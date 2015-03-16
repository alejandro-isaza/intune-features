//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

#import "RecordViewController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/AccumulatorModule.h>
#include <tempo/modules/MicrophoneModule.h>
#include <tempo/modules/SaveToFileModule.h>

using namespace tempo;

static const float kSampleRate = 44100;
static const NSTimeInterval kWaveformMaxDuration = 5;
static const std::size_t packetSize = 1024;

@interface RecordViewController ()

@property(nonatomic, weak) IBOutlet VMWaveformView* waveformView;
@property(nonatomic, weak) IBOutlet UIButton* startStopButton;

@property(nonatomic) std::shared_ptr<MicrophoneModule> microphoneModule;
@property(nonatomic) std::shared_ptr<AccumulatorModule> accumulatorModule;

@end


@implementation RecordViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _waveformView.backgroundColor = [UIColor whiteColor];
    _waveformView.lineColor = [UIColor blueColor];
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
    tempo::UniqueBuffer<float> buffer(packetSize);
    tempo::UniqueBuffer<float>::SizeType size = 0;
    size = _microphoneModule->render(buffer);
    while (size > 0) {
        (*_accumulatorModule)(buffer.data(), size);
        size = _microphoneModule->render(buffer);
    }
}

- (void)initializeModuleGraph {
    _waveformView.sampleRate = kSampleRate;
    _waveformView.duration = kWaveformMaxDuration;
    
    std::size_t capacity = kSampleRate * kWaveformMaxDuration;
    _accumulatorModule.reset(new AccumulatorModule(capacity));
    _accumulatorModule->connect([self](const float* data, std::size_t size) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            [self.waveformView setSamples:data count:size];
        });
    });

    _microphoneModule.reset(new MicrophoneModule);
    _microphoneModule->onDataAvailable([self](std::size_t size) {
        [self step];
    });
}

@end
