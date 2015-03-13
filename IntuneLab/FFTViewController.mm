//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTViewController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/FFTModule.h>
#include <tempo/modules/SineWaveGeneratorModule.h>
#include <tempo/modules/MicrophoneModule.h>

using namespace tempo;


@interface FFTViewController ()

@property(nonatomic, weak) IBOutlet VMEqualizerView* equalizerView;
@property(nonatomic, weak) IBOutlet UIButton* startStopButton;

@property(nonatomic) std::shared_ptr<SineWaveGeneratorModule> generatorModule;
@property(nonatomic) std::shared_ptr<FFTModule> fftModule;

@property(weak, nonatomic) NSTimer* timer;

@end


@implementation FFTViewController

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
    if (!_timer)
        [self start];
    else
        [self stop];
}

- (void)start {
    if (!_generatorModule)
        [self initializeModuleGraph];

    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0 target:self selector:@selector(step) userInfo:nil repeats:YES];

    [self.startStopButton setTitle:@"Stop" forState:UIControlStateNormal];
}

- (void)stop {
    if (!_generatorModule)
        return;

    [_timer invalidate];

    [self.startStopButton setTitle:@"Record" forState:UIControlStateNormal];
}

- (void)step {
    float audioData[1024];
    float fftData[1024];
    _generatorModule->render(0, 1024, audioData);
    _fftModule->process(1024, audioData, fftData);
    [self.equalizerView setSamples:fftData count:512];
}

- (void)initializeModuleGraph {
    _generatorModule.reset(new SineWaveGeneratorModule());
    _generatorModule->setFrequency(1000);
    _fftModule.reset(new FFTModule{1024});
}

@end
