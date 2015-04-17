//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "WaveformViewController.h"
#import "IntuneLab-Swift.h"

#import "VMFileLoader.h"
#import "VMFilePickerController.h"
#import <tempo/modules/ReadFromFileModule.h>

using namespace tempo;
using DataType = ReadFromFileModule::DataType;


@interface WaveformViewController ()

@property (weak, nonatomic) IBOutlet VMWaveformView *waveformView;
@property (strong, nonatomic) VMFileLoader* fileLoader;

@end


@implementation WaveformViewController

- (IBAction)openFile:(UIButton*)sender {
    VMFilePickerController *filePicker = [[VMFilePickerController alloc] init];
    filePicker.selectionBlock = ^(NSString* file, NSString* filename) {
        [self loadWaveform:file];
    };
    [filePicker presentInViewController:self sourceRect:sender.frame];
}

- (void)loadWaveform:(NSString*)file {
    self.fileLoader = [VMFileLoader fileLoaderWithPath:file];
    [self.fileLoader loadAudioData:^(const tempo::Buffer<double>& buffer) {
        [self.waveformView setSamples:buffer.data() count:buffer.capacity()];
    }];
}

@end
