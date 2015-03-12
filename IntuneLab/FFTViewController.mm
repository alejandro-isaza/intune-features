//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTViewController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/FFTModule.h>
#include <tempo/modules/MicrophoneModule.h>

using namespace tempo;

static const float kSampleRate = 44100;


@interface FFTViewController ()

@property(nonatomic, weak) IBOutlet VMEqualizerView* equalizerView;
@property(nonatomic, weak) IBOutlet UIButton* startStopButton;

@property(nonatomic) std::shared_ptr<MicrophoneModule> microphoneModule;
@property(nonatomic) std::shared_ptr<FFTModule> fftModule;

@end


@implementation FFTViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _equalizerView.backgroundColor = [UIColor whiteColor];
    _equalizerView.barColor = [UIColor blueColor];
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

- (void)initializeModuleGraph {
    _microphoneModule.reset(new MicrophoneModule{kSampleRate});
    _fftModule.reset(new FFTModule{_microphoneModule->packetSize()});

    auto fftModule = _fftModule.get();
    _microphoneModule->connect([fftModule](const float* data, std::size_t size) { (*fftModule)(data, size); });

    _fftModule->connect([self](const float* data, std::size_t size) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            [self.equalizerView setSamples:data count:size];
        });
    });
}

@end
