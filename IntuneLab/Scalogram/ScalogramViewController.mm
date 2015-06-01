//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "ScalogramViewController.h"
#import "IntuneLab-Swift.h"

#import "FFTSettingsViewController.h"
#import "VMFilePickerController.h"
#import "VMMidiPickerController.h"
#import "FrequencyGenerator.h"

#include <tempo/algorithms/Scalogram.h>
#include <tempo/modules/MicrophoneModule.h>
#include <tempo/modules/Normalize.h>
#include <tempo/modules/ReadFromFileModule.h>

using namespace tempo;


static const NSTimeInterval kWaveformDuration = 1;
static const float kSampleRate = 44100;
static const DataType kGainValue = 4.0;

@interface ScalogramViewController ()  <UIScrollViewDelegate>

@property(nonatomic, weak) IBOutlet UIView* topContainerView;
@property(nonatomic, weak) IBOutlet UIView* bottomContainerView;
@property(nonatomic, weak) IBOutlet UIView* waveformContainerView;
@property(nonatomic, weak) IBOutlet UIView* windowView;
@property(nonatomic, weak) IBOutlet UILabel* notesLabel;
@property(nonatomic, weak) IBOutlet NSLayoutConstraint* windowWidthConstraint;

@property(nonatomic, strong) VMFrequencyView* topScalogramView;
@property(nonatomic, strong) VMFrequencyView* topSmoothedView;
@property(nonatomic, strong) VMFrequencyView* topMidiView;
@property(nonatomic, strong) VMFrequencyView* bottomScalogramView;
@property(nonatomic, strong) VMFrequencyView* bottomSmoothedView;
@property(nonatomic, strong) VMFrequencyView* bottomMidiView;
@property(nonatomic, strong) NSArray* frequencyViews;

@property(nonatomic, strong) VMWaveformView* waveformView;
@property(nonatomic, assign) NSUInteger frameOffset;

@property(nonatomic) CGPoint previousPoint;
@property(nonatomic) CGFloat previousScale;
@property(nonatomic) CGFloat frequencyZoom;

@property(nonatomic, strong) VMMidiPickerController* midiPicker;
@property(nonatomic, strong) NSSet* midiNotes;

@end

@implementation ScalogramViewController {
    tempo::Scalogram::Parameters _params;
    std::valarray<DataType> _input;
    std::unique_ptr<tempo::Scalogram> _sourceScalogram;
    tempo::MicrophoneModule* _microphone;
    tempo::Scalogram::Data _referenceScalogramData;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _frequencyZoom = 0.25;

    __weak ScalogramViewController *wself = self;
    _midiPicker = [[VMMidiPickerController alloc] init];
    _midiPicker.selectionBlock = ^(NSSet* midiNotes) {
        wself.midiNotes = midiNotes;
        //[wself renderMIDI];
    };

    _topScalogramView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _topSmoothedView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _topMidiView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _bottomSmoothedView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _bottomScalogramView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _bottomMidiView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _frequencyViews = @[_topScalogramView,
                        _topSmoothedView,
                        _topMidiView,
                        _bottomSmoothedView,
                        _bottomScalogramView,
                        _bottomMidiView];

    [self loadContainerView:_topContainerView spectrogram:_topScalogramView smoothed:_topSmoothedView midi:_topMidiView];
    [self loadContainerView:_bottomContainerView spectrogram:_bottomScalogramView smoothed:_bottomSmoothedView midi:_bottomMidiView];
    [self loadWaveformView];
    [self initializeSourceGraph];

    NSString* file = [[NSBundle mainBundle] pathForResource:[@"Audio" stringByAppendingPathComponent:@"twinkle_twinkle"] ofType:@"caf"];
    [self loadFile:file];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateWindowView];
}

- (void)loadContainerView:(UIView*)containerView spectrogram:(VMFrequencyView*)spectrogram smoothed:(VMFrequencyView*)smoothed midi:(VMFrequencyView*)midi {
    spectrogram.frame = containerView.bounds;
    spectrogram.userInteractionEnabled = NO;
    spectrogram.translatesAutoresizingMaskIntoConstraints = NO;
    spectrogram.backgroundColor = [UIColor clearColor];
    spectrogram.lineColor = [UIColor grayColor];
    spectrogram.frequencyZoom = _frequencyZoom;
    [containerView addSubview:spectrogram];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{@"view": spectrogram}]];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{@"view": spectrogram}]];

    smoothed.frame = containerView.bounds;
    smoothed.userInteractionEnabled = NO;
    smoothed.translatesAutoresizingMaskIntoConstraints = NO;
    smoothed.backgroundColor = [UIColor clearColor];
    smoothed.lineColor = [UIColor blackColor];
    smoothed.frequencyZoom = _frequencyZoom;
    [containerView addSubview:smoothed];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{@"view": smoothed}]];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{@"view": smoothed}]];

    midi.frame = containerView.bounds;
    midi.userInteractionEnabled = NO;
    midi.translatesAutoresizingMaskIntoConstraints = NO;
    midi.backgroundColor = [UIColor clearColor];
    midi.lineColor = [UIColor blueColor];
    midi.frequencyZoom = _frequencyZoom;
    midi.peaks = YES;
    midi.peaksIntensity = YES;
    [containerView addSubview:midi];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{@"view": midi}]];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{@"view": midi}]];
}

- (void)loadWaveformView {
    _waveformView = [[VMWaveformView alloc] initWithFrame:_waveformContainerView.bounds];
    _waveformView.visibleDuration = kWaveformDuration;
    _waveformView.translatesAutoresizingMaskIntoConstraints = NO;
    _waveformView.backgroundColor = [UIColor clearColor];
    _waveformView.lineColor = [UIColor blueColor];
    _waveformView.delegate = self;
    [_waveformContainerView addSubview:_waveformView];
    [_waveformContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{@"view": _waveformView}]];
    [_waveformContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{@"view": _waveformView}]];
}

//- (void)renderMIDI {
//    const auto sliceSize = _params.spectrogram.sliceSize();
//    if (_midiData.capacity() != sliceSize)
//        _midiData.reset(sliceSize);
//
//    std::fill(_midiData.data(), _midiData.data() + sliceSize, 0);
//    for (NSNumber *midiNote in _midiNotes)
//        FrequencyGenerator<DataType>::generate([midiNote intValue], _midiData, kSampleRate);
//    [_topMidiView setData:_midiData.data() frequencies:NULL count:sliceSize];
//    [_bottomMidiView setData:_midiData.data() frequencies:NULL count:sliceSize];
//}

- (void)renderReference {
    [_bottomScalogramView setData:nullptr frequencies:nullptr count:0];
    [_bottomSmoothedView setData:nullptr frequencies:nullptr count:0];

    if (!self.referenceFilePath)
        return;

    const auto sliceSize = _params.sliceSize();

    _referenceScalogramData = Scalogram::generateFromData(std::begin(_input) + _frameOffset, _params.widthMax, _params, true);
    if (_referenceScalogramData.sliceCount == 0)
        return;
    
    [_bottomScalogramView setData:std::begin(_referenceScalogramData.magnitudes) + (_referenceScalogramData.sliceCount/2) * sliceSize
                      frequencies:std::begin(_referenceScalogramData.frequencies) + (_referenceScalogramData.sliceCount/2) * sliceSize
                            count:sliceSize];

    [_bottomSmoothedView setData:std::begin(_referenceScalogramData.magnitudes) frequencies:NULL count:sliceSize];

    //[self renderMIDI];
}

- (void)renderSource {
    const auto sliceSize = _params.sliceSize();

    if (!_sourceScalogram || !_sourceScalogram->render())
        return;

    [_topScalogramView setData:std::begin(_sourceScalogram->magnitudes())
                     frequencies:std::begin(_sourceScalogram->frequencies())
                           count:sliceSize];

    [_topSmoothedView setData:std::begin(_sourceScalogram->magnitudes()) frequencies:NULL count:sliceSize];

//    NSMutableString* labelText = [NSMutableString string];
//    auto result = _closestPeaks->nextMatches(0.01);
//    for (auto& annotation : result.annotations) {
//        for (auto& item : annotation.onNoteDurations())
//            [labelText appendFormat:@"%d(%d)", item.first, (int)item.second.count()];
//        [labelText appendFormat:@"  "];
//    }
//    self.notesLabel.text = labelText;
}

- (IBAction)openFile:(UIButton*)sender {
    VMFilePickerController *filePicker = [[VMFilePickerController alloc] init];
    filePicker.selectionBlock = ^(NSString* file, NSString* filename) {
        [self loadFile:file];
    };
    [filePicker presentInViewController:self sourceRect:sender.frame];
}

- (IBAction)openNotes:(UIButton*)sender {
    [_midiPicker presentInViewController:self sourceRect:sender.frame];
}

- (void)loadFile:(NSString*)file {
    self.referenceFilePath = file;

    if (file) {
        ReadFromFileModule reader{self.referenceFilePath.UTF8String};
        _input.resize(reader.availableSize());
        reader.render(std::begin(_input), _input.size());

        Normalize norm{_input};
        norm.render(std::begin(_input), _input.size());

        [self.waveformView setSamples:std::begin(_input) count:_input.size()];
        [self renderReference];
    }

//    if (file) {
//        _closestPeaks->setReferenceFile([file UTF8String]);
//        NSString* annotationsFile = [VMFilePickerController annotationsForFilePath:file];
//        if (annotationsFile)
//            _closestPeaks->setReferenceAnnotationsFile([annotationsFile UTF8String]);
//    }
}

- (void)updateWindowView {
    CGFloat windowWidth = (CGFloat)_params.widthMax / (CGFloat)_waveformView.samplesPerPoint;
    UIEdgeInsets insets = UIEdgeInsetsZero;
    insets.left = (_windowView.bounds.size.width - windowWidth) / 2;
    insets.right = (_windowView.bounds.size.width - windowWidth) / 2;;

    _waveformView.contentInset = insets;
    _windowWidthConstraint.constant = windowWidth;
    [_windowView setNeedsLayout];
}

- (void)initializeSourceGraph {
    // Clear views to avoid accessing invalid memory
    [_topScalogramView setData:nullptr frequencies:nullptr count:0];
    [_topSmoothedView setData:nullptr frequencies:nullptr count:0];

    _sourceScalogram.reset(new Scalogram{_params, kGainValue});

//    // Set up note tracker
//    _closestPeaks.reset(new ClosestPeaks);
//    _closestPeaks->setParameters(_params);
//    _closestPeaks->setSource(_audioSplitter);
//    _audioSplitter->addNode();
//    if (self.fileLoader) {
//        _closestPeaks->setReferenceFile([self.fileLoader.filePath UTF8String]);
//        NSString* annotationsFile = [VMFilePickerController annotationsForFilePath:self.fileLoader.filePath];
//        if (annotationsFile)
//            _closestPeaks->setReferenceAnnotationsFile([annotationsFile UTF8String]);
//    }

    __weak ScalogramViewController* wself = self;
    _microphone = dynamic_cast<MicrophoneModule*>(_sourceScalogram->graph().source()->module.get());
    _microphone->onDataAvailable([wself](std::size_t size) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [wself renderSource];
        });
    });

    _microphone->start();
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView*)scrollView {
    if (!self.referenceFilePath)
        return;

    _frameOffset = MAX(0, _waveformView.samplesPerPoint * (_waveformView.contentOffset.x + _waveformView.contentInset.left));
    [self renderReference];
}


#pragma mark - Gesture Recognizers

- (IBAction)pinchRecognizer:(UIPinchGestureRecognizer*)recognizer {
    CGFloat scale = recognizer.scale;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _previousScale = scale;
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGFloat delta = _previousScale - scale;
        delta *= _bottomSmoothedView.bounds.size.width / _bottomSmoothedView.contentSize.width;
        _previousScale = scale;

        _frequencyZoom += delta;
        if (_frequencyZoom < 0)
            _frequencyZoom = 0;
        if (_frequencyZoom > 1)
            _frequencyZoom = 1;

        for (VMFrequencyView* frequencyView in _frequencyViews)
            frequencyView.frequencyZoom = _frequencyZoom;
    }
}

- (IBAction)panRecognizer:(UIPanGestureRecognizer*)recognizer {
    CGPoint point = [recognizer translationInView:self.view];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _previousPoint = point;
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGFloat delta = _previousPoint.x - point.x;
        _previousPoint = point;

        CGPoint offset = _bottomSmoothedView.contentOffset;
        offset.x += delta;
        if (offset.x < 0)
            offset.x = 0;
        if (offset.x > _bottomSmoothedView.contentSize.width - _bottomSmoothedView.bounds.size.width)
            offset.x = _bottomSmoothedView.contentSize.width - _bottomSmoothedView.bounds.size.width;
        
        for (VMFrequencyView* frequencyView in _frequencyViews)
            frequencyView.contentOffset = offset;
    }
}

- (IBAction)tapRecognizer:(UITapGestureRecognizer*)recognizer {
    if (_microphone->isRunning())
        _microphone->stop();
    else
        _microphone->start();
}

@end
