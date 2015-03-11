//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

#import "RecordViewController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/AccumulatorModule.h>
#include <tempo/modules/MicrophoneModule.h>
#include <tempo/modules/SaveToFileModule.h>

using namespace tempo;

static const float kSampleRate = 44100;
static const NSTimeInterval kWaveformMaxDuration = 5;

@interface RecordViewController ()

@property(nonatomic, weak) IBOutlet VMWaveformView* waveformView;
@property(nonatomic, weak) IBOutlet UIButton* startStopButton;

@property(nonatomic) std::shared_ptr<MicrophoneModule> microphoneModule;
@property(nonatomic) std::shared_ptr<AccumulatorModule> accumulatorModule;
@property(nonatomic) std::shared_ptr<SaveToFileModule> saveToFileModule;

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

    auto accumulatorModule = _accumulatorModule.get();
    _microphoneModule.reset(new MicrophoneModule);
    _microphoneModule->connect([accumulatorModule](const float* data, std::size_t size) { (*accumulatorModule)(data, size); });

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString* filePath = [basePath stringByAppendingPathComponent:@"saved.caf"];
    NSLog(@"Saving to %@", filePath);

    _saveToFileModule.reset(new SaveToFileModule(filePath.UTF8String, kSampleRate));
    
    auto saveToFileModule = _saveToFileModule.get();
    _microphoneModule->connect([saveToFileModule](const float* data, std::size_t size) { (*saveToFileModule)(data, size); });
}

@end
