//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTViewController.h"
#import "IntuneLab-Swift.h"

#import "VMFilePickerController.h"
#import "FFTSettingsViewController.h"

#include <tempo/modules/Converter.h>
#include <tempo/modules/FFTModule.h>
#include <tempo/modules/FixedData.h>
#include <tempo/modules/HammingWindow.h>
#include <tempo/modules/PeakExtraction.h>
#include <tempo/modules/PollingModule.h>
#include <tempo/modules/ReadFromFileModule.h>
#include <tempo/modules/WindowingModule.h>

using namespace tempo;
using DataType = double;
using SizeType = SourceModule<DataType>::SizeType;


static const double kSampleRate = 44100;
static const SizeType kMaxDataSize = 128*1024*1024;


@interface FFTViewController ()

@property(nonatomic, strong) FFTSettingsViewController* settingsViewController;
@property(nonatomic, weak) IBOutlet UIView* settingsViewContainer;
@property(nonatomic, weak) IBOutlet VMSpectrogramView* spectrogramView;
@property(nonatomic, weak) IBOutlet UIButton* openButton;

@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, strong) NSString* filePath;

@end


@implementation FFTViewController {
    std::unique_ptr<DataType[]> _data;
    std::unique_ptr<DataType[]> _peaks;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    _queue = dispatch_queue_create("FFTViewController", DISPATCH_QUEUE_SERIAL);

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _settingsViewController = [FFTSettingsViewController createWithSampleRate:kSampleRate];
    [self addChildViewController:_settingsViewController];
    _settingsViewController.view.frame = _settingsViewContainer.bounds;
    [_settingsViewContainer addSubview:_settingsViewController.view];
    [_settingsViewController didMoveToParentViewController:self];

    __weak FFTViewController *wself = self;
    _settingsViewController.didChangeTimings = ^(NSTimeInterval windowTime, NSTimeInterval hopTime) {
        wself.windowTime = windowTime;
        wself.hopTime = hopTime;
        dispatch_async(wself.queue, ^() {
            [wself render];
        });
    };
    _settingsViewController.didChangeDecibelGround = ^(double decibelGround) {
        wself.spectrogramView.decibelGround = decibelGround;
    };

    _windowTime = _settingsViewController.windowTime;
    _hopTime = _settingsViewController.hopTime;
}

- (IBAction)openFile:(UIButton*)sender {
    VMFilePickerController *filePicker = [[VMFilePickerController alloc] init];
    filePicker.selectionBlock = ^(NSString* file, NSString* filename) {
        [self loadWaveform:file];
    };
    [filePicker presentInViewController:self sourceRect:sender.frame];
}

- (void)loadWaveform:(NSString*)file {
    self.filePath = file;
    dispatch_async(_queue, ^() {
        [self render];
    });
}

- (void)render {
    if (!self.filePath)
        return;

    dispatch_sync(dispatch_get_main_queue(), ^{
        self.spectrogramView.frequencyBinCount = 0;
        [self.spectrogramView setSamples:nullptr count:0];
        self.spectrogramView.peaks = nullptr;
    });

    auto fileModule = std::make_shared<ReadFromFileModule>(self.filePath.UTF8String);
    const auto fileLength = fileModule->lengthInFrames();

    auto converter = std::make_shared<Converter<ReadFromFileModule::DataType, DataType>>();
    converter->setSource(fileModule);

    const auto windowSize = static_cast<SizeType>(_windowTime * kSampleRate);
    auto hopSize = static_cast<SizeType>(_hopTime * kSampleRate);
    if (fileLength / hopSize >= kMaxDataSize / windowSize) {
        hopSize = static_cast<decltype(hopSize)>(static_cast<uint64_t>(fileLength) * static_cast<uint64_t>(windowSize) / kMaxDataSize);

        dispatch_async(dispatch_get_main_queue(), ^{
            _hopTime = static_cast<NSTimeInterval>(hopSize) / kSampleRate;
            _settingsViewController.hopTime = _hopTime;
        });
    }

    auto windowingModule = std::make_shared<WindowingModule<DataType>>(windowSize, hopSize);
    windowingModule->setSource(converter);

    auto windowModule = std::make_shared<HammingWindow<DataType>>();
    windowModule->setSource(windowingModule);

    auto fftModule = std::make_shared<FFTModule<DataType>>(windowSize);
    fftModule->setSource(windowModule);

    auto pollingModule = std::make_shared<PollingModule<DataType>>();
    pollingModule->setSource(fftModule);

    const auto dataLength = (fileLength / hopSize) * windowSize;

    // Render spectrogram
    _data.reset(new DataType[dataLength]);
    PointerBuffer<DataType> buffer(_data.get(), dataLength);
    auto rendered = pollingModule->render(buffer);

    // Render peaks
    auto fixedData = std::make_shared<FixedData<DataType>>(_data.get(), rendered);
    auto window = std::make_shared<WindowingModule<DataType>>(windowSize/2, windowSize/2);
    window->setSource(fixedData);
    auto peakExtraction = std::make_shared<PeakExtraction<DataType>>(windowSize/2);
    peakExtraction->setSource(window);
    auto peakPolling = std::make_shared<PollingModule<DataType>>();
    peakPolling->setSource(peakExtraction);

    _peaks.reset(new DataType[rendered]);
    PointerBuffer<DataType> peakBuffer(_peaks.get(), rendered);
    peakPolling->render(peakBuffer);

    dispatch_sync(dispatch_get_main_queue(), ^() {
        // Fill buffers on main thread or we may write over a buffer being drawn
        self.spectrogramView.sampleTimeLength = _hopTime;
        self.spectrogramView.frequencyBinCount = windowSize / 2;
        [self.spectrogramView setSamples:_data.get() count:rendered];
        self.spectrogramView.peaks = _peaks.get();
    });
}

@end
