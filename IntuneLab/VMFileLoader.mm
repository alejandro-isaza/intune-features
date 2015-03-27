//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMFileLoader.h"

#include <tempo/modules/Converter.h>
#include <tempo/modules/FixedData.h>
#include <tempo/modules/Normalize.h>
#include <tempo/modules/PeakExtraction.h>
#include <tempo/modules/PollingModule.h>
#include <tempo/modules/ReadFromFileModule.h>
#include <tempo/modules/WindowingModule.h>
#include <tempo/algorithms/Spectrogram.h>

using namespace tempo;
using DataType = VMFileLoaderDataType;

static const SizeType kMaxDataSize = 128*1024*1024;


@interface VMFileLoader ()

@property(nonatomic, strong) NSString* filePath;
@property(nonatomic, strong) dispatch_queue_t queue;

@end


@implementation VMFileLoader {
    UniqueBuffer<DataType> _audioData;
    UniqueBuffer<DataType> _peakData;
    UniqueBuffer<DataType> _spectrogramData;
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
    _hopFraction = 0.5;
    _normalize = YES;
    _queue = dispatch_queue_create("VMFileLoader", DISPATCH_QUEUE_SERIAL);
    return self;
}

- (NSTimeInterval)windowTime {
    return static_cast<NSTimeInterval>(_windowSize) / _sampleRate;
}

- (NSTimeInterval)hopTime {
    return static_cast<NSTimeInterval>(self.hopSize) / _sampleRate;
}

- (std::size_t)hopSize {
    return static_cast<std::size_t>(std::round(_windowSize * _hopFraction));
}

- (const tempo::Buffer<DataType>&)audioData {
    return _audioData;
}

- (const tempo::Buffer<DataType>&)spectrogramData {
    return _spectrogramData;
}

- (const tempo::Buffer<VMFileLoaderDataType>&)peakData {
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

    _audioData.reset(fileLength);

    if (self.normalize) {
        auto normalize = std::make_shared<Normalize<DataType>>();
        normalize->setSource(converter);
        normalize->render(_audioData);
    } else {
        converter->render(_audioData);
    }
    
    dispatch_sync(dispatch_get_main_queue(), ^() {
        if (completion)
            completion(_audioData);
    });
}

- (void)loadSpectrogramData:(VMFileLoaderLoadedBlock)completion {
    dispatch_async(self.queue, ^() {
        [self _loadSpectrogramData:completion];
    });
}

- (void)_loadSpectrogramData:(VMFileLoaderLoadedBlock)completion {
    if (_audioData.capacity() == 0) {
        [self _loadAudioData:^(const Buffer<DataType>& buffer) {
            [self loadSpectrogramData:completion];
        }];
        return;
    }

    // Cap hop size to avoid memory overflow
    const auto fileLength = _audioData.capacity();
    if (fileLength / self.hopSize >= kMaxDataSize / _windowSize) {
        const auto hopSize = static_cast<uint64_t>(fileLength) * static_cast<uint64_t>(_windowSize) / kMaxDataSize;
        _hopFraction = hopSize / _windowSize;
    }

    Spectrogram::Parameters params;
    params.sampleRate = _sampleRate;
    params.windowSizeLog2 = std::round(std::log2(_windowSize));
    params.hopFraction = _hopFraction;
    params.normalize = _normalize;
    _spectrogramData = Spectrogram::generateFromData(_audioData.data(), fileLength, params);

    dispatch_sync(dispatch_get_main_queue(), ^() {
        if (completion)
            completion(_spectrogramData);
    });
}

- (void)loadPeakData:(VMFileLoaderLoadedBlock)completion {
    dispatch_async(self.queue, ^() {
        [self _loadPeakData:completion];
    });
}

- (void)_loadPeakData:(VMFileLoaderLoadedBlock)completion {
    const auto spectrogramSize = _spectrogramData.capacity();

    auto fixedData = std::make_shared<FixedData<DataType>>(_spectrogramData.data(), spectrogramSize);

    auto adapter = std::make_shared<FixedSourceToSourceAdapterModule<DataType>>();
    adapter->setSource(fixedData);

    auto window = std::make_shared<WindowingModule<DataType>>(_windowSize/2, _windowSize/2);
    window->setSource(adapter);

    auto peakExtraction = std::make_shared<PeakExtraction<DataType>>(_windowSize/2);
    peakExtraction->setSource(window);

    auto peakPolling = std::make_shared<PollingModule<DataType>>();
    peakPolling->setSource(peakExtraction);

    _peakData.reset(spectrogramSize);
    peakPolling->render(_peakData);

    dispatch_sync(dispatch_get_main_queue(), ^() {
        if (completion)
            completion(_peakData);
    });
}

@end
