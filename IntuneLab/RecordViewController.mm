//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

#import "RecordViewController.h"
#import "IntuneLab-Swift.h"

#include <tempo/modules/AccumulatorModule.h>
#include <tempo/modules/MicrophoneModule.h>
#include <tempo/modules/SaveToFileModule.h>

using namespace tempo;

static const float kSampleRate = 44100;
static const NSTimeInterval kWaveformMaxDuration = 5;
static const std::size_t kPacketSize = 1024;

@interface RecordViewController () <UIAlertViewDelegate, UITextFieldDelegate>

@property(nonatomic, weak) IBOutlet VMWaveformView* waveformView;
@property(nonatomic, weak) IBOutlet UIButton* startStopButton;
@property(nonatomic, weak) IBOutlet UITextField *filenameTextField;

@property(nonatomic) std::shared_ptr<MicrophoneModule> microphoneModule;
@property(nonatomic) std::shared_ptr<AccumulatorModule<MicrophoneModule::DataType>> accumulatorModule;
@property(nonatomic) std::shared_ptr<SaveToFileModule> fileWriter;

@end


@implementation RecordViewController {
    std::unique_ptr<double[]> _displayData;
    std::size_t _displayDataSize;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)startStop {
    if (!_microphoneModule || !_microphoneModule->isRunning())
        [self tryStart];
    else
        [self stop];
}

- (IBAction)save {
    if (!_microphoneModule)
        return;

    [self reset];
    _fileWriter.reset();
    [[[UIAlertView alloc] initWithTitle:@"Recording saved"
                                message:@"\U0001F604" delegate:nil
                      cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)tryStart {
    if (!_microphoneModule && [self recordingFileExists]) {
        [[[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"File \"%@\" exists", [self recordingFilename]]
                                    message:@"Overwrite? \U0001F633" delegate:self
                          cancelButtonTitle:@"NO" otherButtonTitles:@"YES", nil] show];
        return;
    }

    [self start];
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

- (void)reset {
    if (!_microphoneModule)
        return;

    [self stop];
    _microphoneModule.reset();
    _accumulatorModule.reset();
    _displayData.reset();
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.waveformView setSamples:nil count:0];
    });
}

- (void)step {
    tempo::UniqueBuffer<float> buffer(kPacketSize);
    auto size = _accumulatorModule->render(buffer);
    _fileWriter->process(buffer.data(), size);

    auto data = _accumulatorModule->data();
    auto totalSize = _accumulatorModule->size();

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
    _fileWriter.reset(new SaveToFileModule([self recordingFile].UTF8String, kSampleRate));

    _waveformView.sampleRate = kSampleRate;
    _waveformView.endFrame = kWaveformMaxDuration * kSampleRate;

    _microphoneModule.reset(new MicrophoneModule);
    __weak RecordViewController* wself = self;
    _microphoneModule->onDataAvailable([wself](std::size_t size) {
        [wself step];
    });

    std::size_t capacity = kSampleRate * kWaveformMaxDuration;
    _accumulatorModule.reset(new AccumulatorModule<MicrophoneModule::DataType>(capacity));
    _accumulatorModule->setSource(_microphoneModule);
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
