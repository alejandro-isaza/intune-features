//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMSpectrogramViewController.h"
#import "IntuneLab-Swift.h"

#import "VMFilePickerController.h"

#include <memory>


using namespace tempo;


@interface VMSpectrogramViewController () <UIScrollViewDelegate>

@property(nonatomic, weak) IBOutlet VMSpectrogramView *spectrogramView;
@property(nonatomic, weak) IBOutlet VMEqualizerView *equalizerView;

@property(nonatomic, assign) CGPoint previousOffset;
@property(nonatomic, assign) NSUInteger highlightedIndex;
@property(nonatomic, copy) NSString* filePath;

@end


@implementation VMSpectrogramViewController {
    std::unique_ptr<Spectrogram> _spectrogram;
}

+ (instancetype)create {
    return [[VMSpectrogramViewController alloc] initWithNibName:@"VMSpectrogramViewController" bundle:nil];
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

- (void)setParameters:(tempo::Spectrogram::Parameters)parameters {
    _parameters = parameters;
    if (self.filePath) {
        _spectrogram.reset(new Spectrogram{_parameters, self.filePath.UTF8String, true});
        [self render];
    }
}

- (void)setDecibelGround:(double)decibelGround {
    _spectrogramView.decibelGround = decibelGround;
    _equalizerView.decibelGround = decibelGround;
    [self render];
}

- (const double*)data {
    return std::begin(_spectrogram->magnitudes());
}

- (const double*)peaks {
    return std::begin(_spectrogram->peaks());
}

- (NSUInteger)dataSize {
    return _spectrogram->magnitudes().size();
}

- (NSUInteger)frequencyBinCount {
    return _parameters.sliceSize();
}

- (IBAction)open:(UIButton *)sender {
    VMFilePickerController *filePicker = [[VMFilePickerController alloc] init];
    filePicker.selectionBlock = ^(NSString* file, NSString* filename) {
        [self loadWaveform:file];
    };
    [filePicker presentInViewController:self sourceRect:sender.frame];
}

- (void)loadWaveform:(NSString*)file {
    self.filePath = file;
    _spectrogram.reset(new Spectrogram{_parameters, self.filePath.UTF8String, true});
    [self render];
}

- (void)render {
    if (!_spectrogram)
        return;

    // Clear existing data to avoid data access errors
    self.spectrogramView.frequencyBinCount = 0;
    self.spectrogramView.peaks = nullptr;
    [self.spectrogramView setSamples:nullptr count:0];
    [self.equalizerView setSamples:nullptr count:0 offset:0];

    // Load spectrogram
    for (auto i = 0; i < _spectrogram->parameters().historySize; i += 1)
        _spectrogram->render();
    self.spectrogramView.sampleTimeLength = _parameters.hopSize() / _parameters.sampleRate;
    self.spectrogramView.frequencyBinCount = _parameters.sliceSize();
    [self.spectrogramView setSamples:std::begin(_spectrogram->magnitudes()) count:_spectrogram->magnitudes().size()];
    [self updateEqualizerToTimeIndex:_highlightedIndex];

    // Load peaks
    self.spectrogramView.peaks = std::begin(_spectrogram->peaks());
}

- (void)updateEqualizerToTimeIndex:(NSUInteger)timeIndex {
    if (!_spectrogram)
        return;
    
    auto& data = _spectrogram->magnitudes();
    if (data.size() == 0)
        return;

    const DataType* sampleStart = std::begin(data) + (timeIndex * _spectrogramView.frequencyBinCount);
    [_equalizerView setSamples:sampleStart count:_spectrogramView.frequencyBinCount offset:timeIndex];

    if (_spectrogram->peaks().size() > 0)
        _equalizerView.peaks = std::begin(_spectrogram->peaks());
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
