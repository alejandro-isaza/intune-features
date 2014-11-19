//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

#import "RecordViewController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/AccumulatorModule.h>
#include <tempo/modules/BlockModule.h>
#include <tempo/modules/MicrophoneModule.h>

using namespace mkit;

static const NSTimeInterval kWaveformMaxDuration = 5;


@interface RecordViewController ()

@property(nonatomic, weak) IBOutlet VMWaveformView* waveformView;
@property(nonatomic, weak) IBOutlet UIButton* startStopButton;

@property(nonatomic) std::shared_ptr<MicrophoneModule> microphoneModule;
@property(nonatomic) std::shared_ptr<AccumulatorModule> accumulatorModule;
@property(nonatomic) std::shared_ptr<BlockModule> blockModule;

@end


@implementation RecordViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.waveformView.backgroundColor = [UIColor whiteColor];
    self.waveformView.lineColor = [UIColor blueColor];
}

- (IBAction)startStop {
    if (!_microphoneModule || !_microphoneModule->isRunning())
        [self start];
    else
        [self stop];
}

- (void)start {
    if (!_microphoneModule) {
        [self initializeModuleGraph];
    }
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
    _blockModule.reset(new BlockModule(^(const SignalPacket& signalPacket) {
        auto& samples = _accumulatorModule->accumulatedOutput();
        dispatch_async(dispatch_get_main_queue(), ^() {
            [self.waveformView setSamples:samples.samples(0) count:samples.size()];
        });
    }));

    SignalDescription signalDescription;
    std::size_t capacity = signalDescription.sampleRate() * kWaveformMaxDuration;
    _accumulatorModule.reset(new AccumulatorModule(signalDescription, capacity));
    _accumulatorModule->addTarget(_blockModule.get());

    _microphoneModule.reset(new MicrophoneModule);
    _microphoneModule->addTarget(_accumulatorModule.get());

}

@end
