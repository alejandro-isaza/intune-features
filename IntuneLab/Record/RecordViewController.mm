//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

#import "RecordViewController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/AccumulatorModule.h>
#include <tempo/modules/MicrophoneModule.h>
#include <tempo/modules/Probe.h>
#include <tempo/modules/SaveToFileModule.h>

using namespace tempo;

static const float kSampleRate = 44100;
static const NSTimeInterval kWaveformMaxDuration = 5;

@interface RecordViewController () <UIAlertViewDelegate, UITextFieldDelegate>

@property(nonatomic, weak) IBOutlet VMWaveformView* waveformView;
@property(nonatomic, weak) IBOutlet UIButton* startStopButton;
@property(nonatomic, weak) IBOutlet UITextField *filenameTextField;

@end


@implementation RecordViewController {
    Graph _graph;
    MicrophoneModule* _microphone;
    AccumulatorModule* _accumulator;

    std::unique_ptr<double[]> _displayData;
    std::size_t _displayDataSize;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)startStop {
    if (!_microphone || !_microphone->isRunning())
        [self tryStart];
    else
        [self stop];
}

- (IBAction)save {
    if (!_microphone)
        return;

    [self reset];
    [[[UIAlertView alloc] initWithTitle:@"Recording saved"
                                message:@"\U0001F604" delegate:nil
                      cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)tryStart {
    if (!_microphone && [self recordingFileExists]) {
        [[[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"File \"%@\" exists", [self recordingFilename]]
                                    message:@"Overwrite? \U0001F633" delegate:self
                          cancelButtonTitle:@"NO" otherButtonTitles:@"YES", nil] show];
        return;
    }

    [self start];
}

- (void)start {
    if (!_microphone)
        [self initializeModuleGraph];

    _microphone->start();
    [self.startStopButton setTitle:@"Stop" forState:UIControlStateNormal];
}

- (void)stop {
    if (!_microphone)
        return;

    _microphone->stop();
    [self.startStopButton setTitle:@"Record" forState:UIControlStateNormal];
}

- (void)reset {
    if (!_microphone)
        return;

    [self stop];
    _microphone = nullptr;
    _accumulator = nullptr;
    _displayData.reset();
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.waveformView setSamples:nil count:0];
    });
}

- (void)step {
    auto data = _accumulator->data();
    auto totalSize = _accumulator->size();

    if (_displayDataSize < kSampleRate * kWaveformMaxDuration) {
        _displayDataSize = kSampleRate * kWaveformMaxDuration;
        _displayData.reset(new double[_displayDataSize]);
    }
    std::copy(data, data + totalSize, _displayData.get());
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.waveformView setSamples:_displayData.get() count:totalSize];
    });
}

- (void)initializeModuleGraph {
    _waveformView.sampleRate = kSampleRate;

    auto source = _graph.setSource<MicrophoneModule>();

    __weak RecordViewController* wself = self;
    _microphone = dynamic_cast<MicrophoneModule*>(source->module.get());
    _microphone->onDataAvailable([wself](std::size_t size) {
        [wself step];
    });

    auto accumulator = _graph.addModule<AccumulatorModule>(kSampleRate * kWaveformMaxDuration);
    _accumulator = dynamic_cast<AccumulatorModule*>(accumulator->module.get());
    _graph.connect(source, accumulator);

    auto writer = _graph.addModule<SaveToFileModule>([self recordingFile].UTF8String, kSampleRate);
    _graph.connect(source, writer);
}


#pragma mark - Save file location

- (NSString*)recordingFilename {
    NSString* filename = @"microphone.caf";
    if (_filenameTextField.text.length > 0)
        filename = [_filenameTextField.text stringByAppendingString:@".caf"];
    return filename;
}

- (NSString*)recordingFile {
    NSString* documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    return [documentsPath stringByAppendingPathComponent:[self recordingFilename]];
}

- (BOOL)recordingFileExists {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self recordingFile] isDirectory:nil];
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1)
        [self start];
}

@end
