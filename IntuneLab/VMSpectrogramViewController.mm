//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMSpectrogramViewController.h"
#import "IntuneLab-Swift.h"

#import "VMFileLoader.h"
#import "VMFilePickerController.h"

#include <tempo/modules/Converter.h>
#include <tempo/modules/FixedData.h>
#include <tempo/modules/FFTModule.h>
#include <tempo/modules/HammingWindow.h>
#include <tempo/modules/PeakExtraction.h>
#include <tempo/modules/PollingModule.h>
#include <tempo/modules/WindowingModule.h>


using namespace tempo;
using DataType = double;

static const double kSampleRate = 44100;


@interface VMSpectrogramViewController () <UIScrollViewDelegate>

@property(nonatomic, weak) IBOutlet VMSpectrogramView *spectrogramView;
@property(nonatomic, weak) IBOutlet VMEqualizerView *equalizerView;

@property(nonatomic, strong) VMFileLoader* fileLoader;
@property(nonatomic, assign) CGPoint previousOffset;
@property(nonatomic, assign) NSUInteger highlightedIndex;

@end


@implementation VMSpectrogramViewController

+ (instancetype)create {
    return [[VMSpectrogramViewController alloc] initWithNibName:@"VMSpectrogramViewController" bundle:nil];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self)
        return nil;

    _windowTime = 0.05;
    _hopTime = _windowTime / 2;

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _spectrogramView.delegate = self;
}

- (void)highlightTimeIndex:(NSUInteger)index {
    _highlightedIndex = index;

    [self updateEqualizerToTimeIndex:index];
    _spectrogramView.highlightTimeIndex = index;
    [_spectrogramView setNeedsDisplay];
}

- (void)setWindowTime:(NSTimeInterval)windowTime hopTime:(NSTimeInterval)hopTime {
    _windowTime = windowTime;
    _hopTime = hopTime;
    [self render];
}

- (void)setDecibelGround:(double)decibelGround {
    _spectrogramView.decibelGround = decibelGround;
    _equalizerView.decibelGround = decibelGround;
    [self render];
}

- (double*)data {
    auto& audioData = [self.fileLoader audioData];
    return audioData.data();
}

- (double*)peaks {
    auto& peakData = [self.fileLoader peakData];
    return peakData.data();
}

- (NSUInteger)dataSize {
    auto& audioData = [self.fileLoader audioData];
    return audioData.capacity();
}

- (NSUInteger)frequencyBinCount {
    const auto windowSize = static_cast<SizeType>(_windowTime * kSampleRate);
    return windowSize / 2;
}

- (void)setSpectrogramHighColor:(UIColor *)spectrogramColor {
    _spectrogramView.highColor = spectrogramColor;
    _equalizerView.barColor = spectrogramColor;
}

- (void)setSpectrogramLowColor:(UIColor *)spectrogramColor {
    _spectrogramView.lowColor = spectrogramColor;
}

- (IBAction)open:(UIButton *)sender {
    VMFilePickerController *filePicker = [[VMFilePickerController alloc] init];
    filePicker.selectionBlock = ^(NSString* file, NSString* filename) {
        [self loadWaveform:file];
    };
    [filePicker presentInViewController:self sourceRect:sender.frame];
}

- (void)loadWaveform:(NSString*)file {
    self.fileLoader = [VMFileLoader fileLoaderWithPath:file];
    [self render];
}

- (void)render {
    self.fileLoader.windowTime = self.windowTime;
    self.fileLoader.hopTime = self.hopTime;
    
    // Clear existing data to avoid data access errors
    self.spectrogramView.frequencyBinCount = 0;
    self.spectrogramView.peaks = nullptr;
    [self.spectrogramView setSamples:nullptr count:0];
    [self.equalizerView setSamples:nullptr count:0 offset:0];

    // Load spectrogram
    [self.fileLoader loadSpectrogramData:^(const Buffer<DataType>& buffer) {
        self.spectrogramView.sampleTimeLength = self.fileLoader.hopTime;
        self.spectrogramView.frequencyBinCount = self.fileLoader.windowSize / 2;
        [self.spectrogramView setSamples:buffer.data() count:buffer.capacity()];
        [self updateEqualizerToTimeIndex:_highlightedIndex];

        // Load peaks
        [self.fileLoader loadPeakData:^(const Buffer<DataType>& buffer) {
            self.spectrogramView.peaks = buffer.data();
        }];
    }];
}

- (void)updateEqualizerToTimeIndex:(NSUInteger)timeIndex {
    auto& data = [self.fileLoader spectrogramData];
    if (!data.data())
        return;

    DataType* sampleStart = data.data() + (timeIndex * _spectrogramView.frequencyBinCount);
    [_equalizerView setSamples:sampleStart count:_spectrogramView.frequencyBinCount offset:timeIndex];

    auto& peaks = [self.fileLoader peakData];
    if (peaks.data())
        _equalizerView.peaks = peaks.data();
}

- (void)scrollBy:(CGFloat)dx {
    CGPoint currentOffset = _spectrogramView.contentOffset;
    currentOffset.x += dx;
    _spectrogramView.contentOffset = currentOffset;
}


#pragma mark - Gestures

- (IBAction)handleTap:(UITapGestureRecognizer *)sender {
    CGPoint tapLocation = [sender locationInView:self.spectrogramView];

    _highlightedIndex = [_spectrogramView timeIndexAtLocation:tapLocation];
    [self updateEqualizerToTimeIndex:_highlightedIndex];
    [self highlightTimeIndex:_highlightedIndex];
    
    if (_didTapBlock) {
        _didTapBlock(tapLocation, _highlightedIndex);
    }
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGPoint currentOffset = scrollView.contentOffset;
    CGFloat dx = currentOffset.x - _previousOffset.x;
    _previousOffset = currentOffset;

    if (_didScrollBlock)
        _didScrollBlock(dx); // hmm maybe send back sample offset?
}

@end
