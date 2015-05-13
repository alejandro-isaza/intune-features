//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "WaveformViewController.h"
#import "IntuneLab-Swift.h"

#import "VMFilePickerController.h"
#import <tempo/modules/ReadFromFileModule.h>

using namespace tempo;


@interface WaveformViewController ()

@property (weak, nonatomic) IBOutlet VMWaveformView *waveformView;
@property (copy, nonatomic) NSString* filePath;

@end


@implementation WaveformViewController {
    std::valarray<DataType> _data;
}

- (IBAction)openFile:(UIButton*)sender {
    VMFilePickerController *filePicker = [[VMFilePickerController alloc] init];
    filePicker.selectionBlock = ^(NSString* file, NSString* filename) {
        [self loadWaveform:file];
    };
    [filePicker presentInViewController:self sourceRect:sender.frame];
}

- (void)loadWaveform:(NSString*)file {
    self.filePath = file;

    ReadFromFileModule reader{self.filePath.UTF8String};
    _data.resize(reader.availableSize());
    reader.render(std::begin(_data), _data.size());

    [self.waveformView setSamples:std::begin(_data) count:_data.size()];
}

@end
