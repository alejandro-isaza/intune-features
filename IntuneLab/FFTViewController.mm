//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTViewController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/FFTModule.h>
#include <tempo/modules/HammingWindow.h>
#include <tempo/modules/MicrophoneModule.h>
#include <tempo/modules/WindowingModule.h>

using namespace tempo;

static const double kSampleRate = 44100;


@interface FFTViewController ()

@property(nonatomic, weak) IBOutlet VMEqualizerView* equalizerView;
@property(nonatomic, weak) IBOutlet UIButton* startStopButton;
@property(nonatomic, strong) dispatch_queue_t queue;

@property(nonatomic) std::shared_ptr<MicrophoneModule> microphoneModule;
@property(nonatomic) std::shared_ptr<WindowingModule> windowingModule;
@property(nonatomic) std::shared_ptr<HammingWindow> windowModule;
@property(nonatomic) std::shared_ptr<FFTModule> fftModule;

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

    _equalizerView.backgroundColor = [UIColor whiteColor];
    _equalizerView.barColor = [UIColor blueColor];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self start];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stop];
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

    std::size_t size;
    UniqueBuffer<float> buffer(binCount);
    do {
        size = _fftModule->render(buffer);
        auto data = buffer.data();
        dispatch_sync(dispatch_get_main_queue(), ^() {
            [self.equalizerView setSamples:data count:size];
        });
    } while (size > 0);
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
    _fftModule->setSource(_windowingModule);
}

@end
