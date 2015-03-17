//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTViewController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/AccumulatorModule.h>
#include <tempo/modules/FFTModule.h>
#include <tempo/modules/HammingWindow.h>
#include <tempo/modules/MicrophoneModule.h>
#include <tempo/modules/WindowingModule.h>

using namespace tempo;

static const double kSampleRate = 44100;
static const NSTimeInterval kMaxDuration = 5;


@interface FFTViewController ()

@property(nonatomic, weak) IBOutlet VMSpectrogramView* spectrogramView;
@property(nonatomic, weak) IBOutlet UISlider* windowSlider;
@property(nonatomic, weak) IBOutlet UISlider* hopSlider;
@property(nonatomic, weak) IBOutlet UITextField* windowTextField;
@property(nonatomic, weak) IBOutlet UITextField* hopTextField;
@property(nonatomic, weak) IBOutlet UIButton* startStopButton;
@property(nonatomic, strong) dispatch_queue_t queue;

@property(nonatomic) std::shared_ptr<MicrophoneModule> microphoneModule;
@property(nonatomic) std::shared_ptr<WindowingModule> windowingModule;
@property(nonatomic) std::shared_ptr<HammingWindow> windowModule;
@property(nonatomic) std::shared_ptr<FFTModule> fftModule;
@property(nonatomic) std::shared_ptr<AccumulatorModule> accumulatorModule;

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

- (void)viewDidLoad {
    [super viewDidLoad];

    const auto windowSize = static_cast<std::size_t>(_windowTime * kSampleRate);
    self.spectrogramView.frequencyCount = windowSize / 2;

    self.windowTextField.text = [NSString stringWithFormat:@"%.0fms", _windowTime * 1000.0];
    self.windowSlider.value = _windowTime * 1000.0;
    self.hopTextField.text = [NSString stringWithFormat:@"%.0fms", _hopTime * 1000.0];
    self.hopSlider.value = _hopTime / _windowTime;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //[self start];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stop];
}

- (IBAction)didChangeWindow {
    _windowTime = self.windowSlider.value / 1000.0;
    _hopTime = self.hopSlider.value * _windowTime;
    [self updateParams];
}

- (IBAction)didChangeHop {
    _hopTime = self.hopSlider.value * _windowTime;
    [self updateParams];
}

- (void)updateParams {
    self.windowTextField.text = [NSString stringWithFormat:@"%.0fms", _windowTime * 1000.0];
    self.hopTextField.text = [NSString stringWithFormat:@"%.0fms", _hopTime * 1000.0];

    const auto windowSize = static_cast<std::size_t>(_windowTime * kSampleRate);

    dispatch_async(_queue, ^() {
        dispatch_sync(dispatch_get_main_queue(), ^() {
            [self.spectrogramView setSamples:NULL count:0];
            self.spectrogramView.frequencyCount = windowSize / 2;
        });
        [self updateModuleGraph];
    });
}

- (IBAction)startStop {
    if (!_microphoneModule || !_microphoneModule->isRunning())
        [self start];
    else
        [self stop];
}

- (void)start {
    if (!_microphoneModule)
        [self initializeModuleGraph];

    _microphoneModule->start();
    [self.startStopButton setTitle:@"Stop" forState:UIControlStateNormal];
}

- (void)stop {
    if (!_microphoneModule)
        return;

    _microphoneModule->stop();
    [self.startStopButton setTitle:@"Record" forState:UIControlStateNormal];
}

- (void)step {
    const auto windowSize = static_cast<std::size_t>(_windowTime * kSampleRate);
    const auto binCount = windowSize / 2;

    UniqueBuffer<float> buffer(binCount);
    auto size = _accumulatorModule->render(buffer);
    while (size > 0)
        size = _accumulatorModule->render(buffer);

    auto data = _accumulatorModule->data();
    size = _accumulatorModule->size();
    dispatch_sync(dispatch_get_main_queue(), ^() {
        [self.spectrogramView setSamples:data count:size];
    });
}

- (void)initializeModuleGraph {
    const auto windowSize = static_cast<std::size_t>(_windowTime * kSampleRate);
    const auto hopSize = static_cast<std::size_t>(_hopTime * kSampleRate);

    _microphoneModule.reset(new MicrophoneModule{kSampleRate});
    _microphoneModule->onDataAvailable([self](std::size_t size) {
        dispatch_async(_queue, ^() {
            [self step];
        });
    });

    _windowingModule.reset(new WindowingModule{windowSize, hopSize});
    _windowingModule->setSource(_microphoneModule);

    _windowModule.reset(new HammingWindow{});
    _windowModule->setSource(_windowingModule);
    
    _fftModule.reset(new FFTModule{windowSize});
    _fftModule->setSource(_windowModule);

    std::size_t capacity = windowSize * kMaxDuration * kSampleRate / 2;
    _accumulatorModule.reset(new AccumulatorModule(capacity));
    _accumulatorModule->setSource(_fftModule);
}

- (void)updateModuleGraph {
    if (!_microphoneModule)
        return;

    const auto windowSize = static_cast<std::size_t>(_windowTime * kSampleRate);
    const auto hopSize = static_cast<std::size_t>(_hopTime * kSampleRate);

    _windowingModule.reset(new WindowingModule{windowSize, hopSize});
    _windowingModule->setSource(_microphoneModule);
    _windowModule->setSource(_windowingModule);

    _fftModule.reset(new FFTModule{windowSize});
    _fftModule->setSource(_windowModule);

    std::size_t capacity = windowSize * kMaxDuration * kSampleRate / 2;
    _accumulatorModule.reset(new AccumulatorModule(capacity));
    _accumulatorModule->setSource(_fftModule);
}

@end
