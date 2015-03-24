//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMFileLoader.h"

#include <tempo/modules/Converter.h>
#include <tempo/modules/FixedData.h>
#include <tempo/modules/FFTModule.h>
#include <tempo/modules/HammingWindow.h>
#include <tempo/modules/Normalize.h>
#include <tempo/modules/PeakExtraction.h>
#include <tempo/modules/PollingModule.h>
#include <tempo/modules/ReadFromFileModule.h>
#include <tempo/modules/WindowingModule.h>

using namespace tempo;
using DataType = VMFileLoaderDataType;
using SizeType = SourceModule<DataType>::SizeType;

static const SizeType kMaxDataSize = 128*1024*1024;


@interface VMFileLoader ()

@property(nonatomic, strong) NSString* filePath;
@property(nonatomic, strong) dispatch_queue_t queue;

@end


@implementation VMFileLoader {
    UniqueBuffer<DataType>* _audioData;
    UniqueBuffer<DataType>* _spectrogramData;
    UniqueBuffer<DataType>* _peakData;
}

+ (instancetype)fileLoaderWithPath:(NSString*)path {
    if (!path)
        return nil;

    VMFileLoader* loader = [[VMFileLoader alloc] init];
    loader.filePath = path;
    return loader;
}

- (instancetype)init {
    self = [super init];
    if (!self)
        return nil;

    _sampleRate = 44100;
    _windowSize = 1024;
    _hopSize = 512;
    _normalize = YES;
    _queue = dispatch_queue_create("VMFileLoader", DISPATCH_QUEUE_SERIAL);
    return self;
}

- (void)dealloc {
    delete _audioData;
    delete _spectrogramData;
    delete _peakData;
}

- (NSTimeInterval)windowTime {
    return static_cast<NSTimeInterval>(_windowSize) / _sampleRate;
}

- (void)setWindowTime:(NSTimeInterval)windowTime {
    _windowSize = std::round(windowTime * _sampleRate);
}

- (NSTimeInterval)hopTime {
    return static_cast<NSTimeInterval>(_hopSize) / _sampleRate;
}

- (void)setHopTime:(NSTimeInterval)hopTime {
    _hopSize = std::round(hopTime * _sampleRate);
}

- (const tempo::Buffer<DataType>*)audioData {
    return _audioData;
}

- (const tempo::Buffer<DataType>*)spectrogramData {
    return _spectrogramData;
}

- (const tempo::Buffer<VMFileLoaderDataType>*)peakData {
    return _peakData;
}

- (void)loadAudioData:(VMFileLoaderLoadedBlock)completion {
    dispatch_async(self.queue, ^() {
        [self _loadAudioData:completion];
    });
}

- (void)_loadAudioData:(VMFileLoaderLoadedBlock)completion {
    auto fileModule = std::make_shared<ReadFromFileModule>(self.filePath.UTF8String);
    const auto fileLength = fileModule->size();

    auto adapter = std::make_shared<FixedSourceToSourceAdapterModule<ReadFromFileModule::DataType>>();
    adapter->setSource(fileModule);

    auto converter = std::make_shared<Converter<ReadFromFileModule::DataType, DataType>>();
    converter->setSource(adapter);

    delete _audioData;
    _audioData = new UniqueBuffer<DataType>(fileLength);

    if (self.normalize) {
        auto normalize = std::make_shared<Normalize<DataType>>();
        normalize->setSource(converter);
        normalize->render(*_audioData);
    } else {
        converter->render(*_audioData);
    }
    
    dispatch_sync(dispatch_get_main_queue(), ^() {
        if (completion)
            completion(*_audioData);
    });
}

- (void)loadSpectrogramData:(VMFileLoaderLoadedBlock)completion {
    dispatch_async(self.queue, ^() {
        [self _loadSpectrogramData:completion];
    });
}

- (void)_loadSpectrogramData:(VMFileLoaderLoadedBlock)completion {
    if (!_audioData) {
        [self _loadAudioData:^(const Buffer<DataType>& buffer) {
            [self loadSpectrogramData:completion];
        }];
        return;
    }

    // Cap hop size to avoid memory overflow
    const auto fileLength = _audioData->capacity();
    if (fileLength / _hopSize >= kMaxDataSize / _windowSize) {
        _hopSize = static_cast<decltype(_hopSize)>(static_cast<uint64_t>(fileLength) * static_cast<uint64_t>(_windowSize) / kMaxDataSize);
    }

    auto fixedAudioData = std::make_shared<FixedData<DataType>>(_audioData->data(), fileLength);

    auto adapter = std::make_shared<FixedSourceToSourceAdapterModule<DataType>>();
    adapter->setSource(fixedAudioData);

    auto windowingModule = std::make_shared<WindowingModule<DataType>>(_windowSize, _hopSize);
    windowingModule->setSource(adapter);

    auto windowModule = std::make_shared<HammingWindow<DataType>>();
    windowModule->setSource(windowingModule);

    auto fftModule = std::make_shared<FFTModule<DataType>>(_windowSize);
    fftModule->setSource(windowModule);

    auto pollingModule = std::make_shared<PollingModule<DataType>>();
    pollingModule->setSource(fftModule);

    const auto frequencyBinCount = _windowSize / 2;
    const auto hopCount = (fileLength - _windowSize + _hopSize) / _hopSize;
    const auto dataLength = hopCount * frequencyBinCount;

    // Render spectrogram
    delete _spectrogramData;
    _spectrogramData = new UniqueBuffer<DataType>(dataLength);
    const auto size = pollingModule->render(*_spectrogramData);
    assert(size == dataLength);

    dispatch_sync(dispatch_get_main_queue(), ^() {
        if (completion)
            completion(*_spectrogramData);
    });
}

- (void)loadPeakData:(VMFileLoaderLoadedBlock)completion {
    dispatch_async(self.queue, ^() {
        [self _loadPeakData:completion];
    });
}

- (void)_loadPeakData:(VMFileLoaderLoadedBlock)completion {
    const auto spectrogramSize = _spectrogramData->capacity();

    auto fixedData = std::make_shared<FixedData<DataType>>(_spectrogramData->data(), spectrogramSize);

    auto adapter = std::make_shared<FixedSourceToSourceAdapterModule<DataType>>();
    adapter->setSource(fixedData);

    auto window = std::make_shared<WindowingModule<DataType>>(_windowSize/2, _windowSize/2);
    window->setSource(adapter);

    auto peakExtraction = std::make_shared<PeakExtraction<DataType>>(_windowSize/2);
    peakExtraction->setSource(window);

    auto peakPolling = std::make_shared<PollingModule<DataType>>();
    peakPolling->setSource(peakExtraction);

    delete _peakData;
    _peakData = new UniqueBuffer<DataType>(spectrogramSize);
    peakPolling->render(*_peakData);

    dispatch_sync(dispatch_get_main_queue(), ^() {
        if (completion)
            completion(*_peakData);
    });
}

@end
