//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "AnnotationViewController.h"

#import "VMFileLoader.h"
#import "VMFilePickerController.h"
#import "IntuneLab-Swift.h"


@interface AnnotationViewController () <UIScrollViewDelegate>

@property(nonatomic, weak) IBOutlet VMSpectrogramView* spectrogramView;
@property(nonatomic, weak) IBOutlet VMWaveformView* waveformView;
@property(nonatomic, weak) IBOutlet UITextField* wallTimeTextField;
@property(nonatomic, weak) IBOutlet UITextField* measureNumberTextField;
@property(nonatomic, weak) IBOutlet UITextField* measureFractionTextField;
@property(nonatomic, weak) IBOutlet UITextField* fileNameTextFielx;
@property(nonatomic, weak) IBOutlet UIButton* openButton;
@property(nonatomic, weak) IBOutlet UIButton* addButton;
@property(nonatomic, weak) IBOutlet UIButton* saveButton;
@property(nonatomic, weak) IBOutlet UILabel* dataPointCountLabel;

@property(nonatomic, strong) VMFileLoader* fileLoader;
@property(nonatomic) NSUInteger selectedIndex;

@end

@implementation AnnotationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.waveformView.alignment = 0;
    self.spectrogramView.delegate = self;
}


#pragma mark - Actions

- (IBAction)open:(UIButton*)sender {
    VMFilePickerController *filePicker = [[VMFilePickerController alloc] init];
    filePicker.selectionBlock = ^(NSString* file, NSString* filename) {
        [self loadWaveform:file];
    };
    [filePicker presentInViewController:self sourceRect:sender.frame];
}

- (void)loadWaveform:(NSString*)file {
    self.fileLoader = [VMFileLoader fileLoaderWithPath:file];
    [self loadAudioData];
}

- (IBAction)add {

}

- (IBAction)save {

}


#pragma mark - Gestures

- (IBAction)handleTap:(UITapGestureRecognizer *)sender {
    CGPoint tapLocation = [sender locationInView:self.spectrogramView];
    self.selectedIndex = [self.spectrogramView timeIndexAtLocation:tapLocation];

    self.spectrogramView.highlightTimeIndex = self.selectedIndex;
    [self.spectrogramView setNeedsDisplay];

    NSTimeInterval time = self.selectedIndex * self.fileLoader.hopTime;
    [self.waveformView markWithTime:time];
    self.wallTimeTextField.text = [NSString stringWithFormat:@"%d", int(1000 * time)];
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSUInteger firstIndex = [self.spectrogramView timeIndexAtLocation:self.spectrogramView.contentOffset];
    NSUInteger lastIndex = [self.spectrogramView timeIndexAtLocation:CGPointMake(self.spectrogramView.contentOffset.x + self.spectrogramView.bounds.size.width, 0)];

    auto audioData = [self.fileLoader audioData];
    if (audioData) {
        self.waveformView.startFrame = firstIndex * self.fileLoader.hopSize;
        self.waveformView.endFrame = lastIndex * self.fileLoader.hopSize;
    }
}


#pragma mark - Data loading

- (void)loadAudioData {
    // Clear existing data to avoid data access errors
    self.spectrogramView.frequencyBinCount = 0;
    [self.spectrogramView setSamples:nullptr count:0];
    [self.waveformView setSamples:nullptr count:0];

    [self.fileLoader loadAudioData:^(const tempo::Buffer<VMFileLoaderDataType>& buffer) {
        [self.waveformView setSamples:buffer.data() count:buffer.capacity()];
        [self loadSpectrogram];
    }];
}

- (void)loadSpectrogram {
    [self.fileLoader loadSpectrogramData:^(const tempo::Buffer<VMFileLoaderDataType>& buffer) {
        self.spectrogramView.sampleTimeLength = self.fileLoader.hopTime;
        self.spectrogramView.frequencyBinCount = self.fileLoader.windowSize / 2;
        [self.spectrogramView setSamples:buffer.data() count:buffer.capacity()];

        NSUInteger firstIndex = [self.spectrogramView timeIndexAtLocation:self.spectrogramView.contentOffset];
        NSUInteger lastIndex = [self.spectrogramView timeIndexAtLocation:CGPointMake(self.spectrogramView.contentOffset.x + self.spectrogramView.bounds.size.width, 0)];
        self.waveformView.startFrame = firstIndex * self.fileLoader.hopSize;
        self.waveformView.endFrame = lastIndex * self.fileLoader.hopSize;
    }];
}

@end
