//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTViewController.h"
#import "VMFilePickerController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/FFTModule.h>
#include <tempo/modules/HammingWindow.h>
#include <tempo/modules/PollingModule.h>
#include <tempo/modules/ReadFromFileModule.h>
#include <tempo/modules/WindowingModule.h>

using namespace tempo;
using DataType = ReadFromFileModule::DataType;
using SizeType = SourceModule<DataType>::SizeType;


static const double kSampleRate = 44100;
static const NSTimeInterval kMaxDuration = 5;
static const SizeType kMaxDataSize = 128*1024*1024;


@interface FFTViewController ()

@property(nonatomic, weak) IBOutlet VMSpectrogramView* spectrogramView;
@property(nonatomic, weak) IBOutlet UISlider* windowSlider;
@property(nonatomic, weak) IBOutlet UISlider* hopSlider;
@property(nonatomic, weak) IBOutlet UISlider* groundSlider;
@property(nonatomic, weak) IBOutlet UITextField* windowTextField;
@property(nonatomic, weak) IBOutlet UITextField* hopTextField;
@property(nonatomic, weak) IBOutlet UITextField* groundTextField;
@property(nonatomic, weak) IBOutlet UIButton* openButton;

@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, strong) NSString* filePath;

@property(nonatomic) float* data;

@end


@implementation FFTViewController

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    _queue = dispatch_queue_create("FFTViewController", DISPATCH_QUEUE_SERIAL);
    _windowTime = 0.05;
    _hopTime = _windowTime / 2;

    return self;
}

- (void)dealloc {
    delete [] _data;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    const auto windowSize = static_cast<SizeType>(_windowTime * kSampleRate);
    self.spectrogramView.frequencyCount = windowSize / 2;

    self.windowTextField.text = [NSString stringWithFormat:@"%.0fms", _windowTime * 1000.0];
    self.windowSlider.value = _windowTime * 1000.0;
    self.hopTextField.text = [NSString stringWithFormat:@"%.0fms", _hopTime * 1000.0];
    self.hopSlider.value = _hopTime / _windowTime;
    self.groundTextField.text = [NSString stringWithFormat:@"%.0fdB", _spectrogramView.decibelGround];
    self.groundSlider.value = _spectrogramView.decibelGround;
}

- (IBAction)didChangeWindow {
    _windowTime = self.windowSlider.value / 1000.0;
    _hopTime = self.hopSlider.value * _windowTime;
    [self updateParams];
}

- (IBAction)didChangeHop {
    _hopTime = self.hopSlider.value * _windowTime;
    if (_hopTime == 0)
        _hopTime = 1.0 / kSampleRate;
    [self updateParams];
}

- (IBAction)didChangeGround {
    self.spectrogramView.decibelGround = self.groundSlider.value;
    self.groundTextField.text = [NSString stringWithFormat:@"%.0fdB", self.spectrogramView.decibelGround];
}

- (void)updateParams {
    self.windowTextField.text = [NSString stringWithFormat:@"%.0fms", _windowTime * 1000.0];
    self.hopTextField.text = [NSString stringWithFormat:@"%.0fms", _hopTime * 1000.0];

    [self.spectrogramView setSamples:NULL count:0];

    dispatch_async(_queue, ^() {
        [self render];
    });
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

    auto fileModule = std::make_shared<ReadFromFileModule>(self.filePath.UTF8String);
    const auto fileLength = fileModule->lengthInFrames();

    const auto windowSize = static_cast<SizeType>(_windowTime * kSampleRate);
    auto hopSize = static_cast<SizeType>(_hopTime * kSampleRate);
    if (fileLength / hopSize >= kMaxDataSize / windowSize) {
        hopSize = static_cast<decltype(hopSize)>(static_cast<uint64_t>(fileLength) * static_cast<uint64_t>(windowSize) / kMaxDataSize);

        dispatch_async(dispatch_get_main_queue(), ^{
            _hopTime = static_cast<NSTimeInterval>(hopSize) / kSampleRate;
            self.hopSlider.value = _hopTime / _windowTime;
            self.hopSlider.minimumValue = _hopTime / _windowTime;
            self.hopTextField.text = [NSString stringWithFormat:@"%.0fms", _hopTime * 1000.0];
        });
    }

    auto windowingModule = std::make_shared<WindowingModule>(windowSize, hopSize);
    windowingModule->setSource(fileModule);

    auto windowModule = std::make_shared<HammingWindow>();
    windowModule->setSource(windowingModule);

    auto fftModule = std::make_shared<FFTModule>(windowSize);
    fftModule->setSource(windowModule);

    auto pollingModule = std::make_shared<PollingModule<DataType>>();
    pollingModule->setSource(fftModule);

    const auto dataLength = (fileLength / hopSize) * windowSize;
    delete [] _data;
    _data = new DataType[dataLength];

    PointerBuffer<DataType> buffer(_data, dataLength);
    auto rendered = pollingModule->render(buffer);
    dispatch_sync(dispatch_get_main_queue(), ^() {
        self.spectrogramView.sampleTimeLength = _hopTime;
        self.spectrogramView.frequencyCount = windowSize / 2;
        [self.spectrogramView setSamples:_data count:rendered];
    });
}

@end
