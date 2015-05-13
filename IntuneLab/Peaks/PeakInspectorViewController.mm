//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "PeakInspectorViewController.h"
#import "IntuneLab-Swift.h"

#import "FFTSettingsViewController.h"
#import "VMFilePickerController.h"
#import "VMMidiPickerController.h"
#import "FrequencyGenerator.h"

#include <tempo/algorithms/NoteTracker.h>
#include <tempo/modules/MicrophoneModule.h>
#include <tempo/modules/ReadFromFileModule.h>

using namespace tempo;


static const NSTimeInterval kWaveformDuration = 1;
static const float kSampleRate = 44100;
static const DataType kGainValue = 4.0;

@interface PeakInspectorViewController ()  <UIScrollViewDelegate>

@property(nonatomic, weak) IBOutlet UIView* topContainerView;
@property(nonatomic, weak) IBOutlet UIView* bottomContainerView;
@property(nonatomic, weak) IBOutlet UIView* waveformContainerView;
@property(nonatomic, weak) IBOutlet UIView* windowView;
@property(nonatomic, weak) IBOutlet UILabel* notesLabel;
@property(nonatomic, weak) IBOutlet NSLayoutConstraint* windowWidthConstraint;

@property(nonatomic, strong) VMFrequencyView* topSpectrogramView;
@property(nonatomic, strong) VMFrequencyView* topPeaksView;
@property(nonatomic, strong) VMFrequencyView* topSmoothedView;
@property(nonatomic, strong) VMFrequencyView* topMidiView;
@property(nonatomic, strong) VMFrequencyView* bottomSpectrogramView;
@property(nonatomic, strong) VMFrequencyView* bottomPeaksView;
@property(nonatomic, strong) VMFrequencyView* bottomSmoothedView;
@property(nonatomic, strong) VMFrequencyView* bottomMidiView;
@property(nonatomic, strong) NSArray* frequencyViews;

@property(nonatomic, strong) VMWaveformView* waveformView;
@property(nonatomic, assign) NSUInteger frameOffset;

@property(nonatomic) CGPoint previousPoint;
@property(nonatomic) CGFloat previousScale;
@property(nonatomic) CGFloat frequencyZoom;

@property(nonatomic, strong) FFTSettingsViewController *settingsViewController;
@property(nonatomic, strong) VMMidiPickerController* midiPicker;
@property(nonatomic, strong) NSSet* midiNotes;

@end

@implementation PeakInspectorViewController {
    tempo::NoteTracker::Parameters _params;
    std::valarray<DataType> _input;
    std::unique_ptr<tempo::Spectrogram> _sourceSpectrogram;
    tempo::MicrophoneModule* _microphone;
    tempo::Spectrogram::Data _referenceSpectrogramData;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _frequencyZoom = 0.25;

    __weak PeakInspectorViewController *wself = self;
    _midiPicker = [[VMMidiPickerController alloc] init];
    _midiPicker.selectionBlock = ^(NSSet* midiNotes) {
        wself.midiNotes = midiNotes;
        //[wself renderMIDI];
    };

    _topSpectrogramView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _topPeaksView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _topSmoothedView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _topMidiView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _bottomPeaksView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _bottomSmoothedView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _bottomSpectrogramView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _bottomMidiView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _frequencyViews = @[_topSpectrogramView,
                        _topPeaksView,
                        _topSmoothedView,
                        _topMidiView,
                        _bottomPeaksView,
                        _bottomSmoothedView,
                        _bottomSpectrogramView,
                        _bottomMidiView];

    [self loadContainerView:_topContainerView spectrogram:_topSpectrogramView smoothed:_topSmoothedView peaks:_topPeaksView midi:_topMidiView];
    [self loadContainerView:_bottomContainerView spectrogram:_bottomSpectrogramView smoothed:_bottomSmoothedView peaks:_bottomPeaksView midi:_bottomMidiView];
    [self loadWaveformView];
    [self loadSettings];
    [self initializeSourceGraph];

    NSString* file = [[NSBundle mainBundle] pathForResource:[@"Audio" stringByAppendingPathComponent:@"twinkle_twinkle"] ofType:@"caf"];
    [self loadFile:file];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateWindowView];
}

- (void)loadContainerView:(UIView*)containerView spectrogram:(VMFrequencyView*)spectrogram smoothed:(VMFrequencyView*)smoothed peaks:(VMFrequencyView*)peaks midi:(VMFrequencyView*)midi {
    peaks.frame = containerView.bounds;
    peaks.userInteractionEnabled = NO;
    peaks.translatesAutoresizingMaskIntoConstraints = NO;
    peaks.backgroundColor = [UIColor clearColor];
    peaks.lineColor = [UIColor redColor];
    peaks.peaks = YES;
    peaks.frequencyZoom = _frequencyZoom;
    [containerView addSubview:peaks];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{@"view": peaks}]];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{@"view": peaks}]];

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

- (void)loadSettings {
    _settingsViewController = [FFTSettingsViewController createWithSampleRate:kSampleRate];
    _settingsViewController.modalPresentationStyle = UIModalPresentationPopover;
    _settingsViewController.preferredContentSize = CGSizeMake(600, 150);

    _params.spectrogram.sampleRate = kSampleRate;
    _params.spectrogram.windowSizeLog2 = std::round(std::log2(_settingsViewController.windowSize));
    _params.spectrogram.hopFraction = _settingsViewController.hopFraction;
    _params.peakWidth = _settingsViewController.peakWidth;

    _topPeaksView.peakWidth = std::max(1.0, _params.peakWidth / _params.spectrogram.baseFrequency());
    _bottomPeaksView.peakWidth = std::max(1.0, _params.peakWidth / _params.spectrogram.baseFrequency());
    _topMidiView.peakWidth = std::max(1.0, _params.peakWidth / _params.spectrogram.baseFrequency());
    _bottomMidiView.peakWidth = std::max(1.0, _params.peakWidth / _params.spectrogram.baseFrequency());
    [self updateWindowView];

    _topSpectrogramView.hidden = !_settingsViewController.spectrogramEnabled;
    _bottomSpectrogramView.hidden = !_settingsViewController.spectrogramEnabled;
    _topSmoothedView.hidden = !_settingsViewController.smoothedSpectrogramEnabled;
    _bottomSmoothedView.hidden = !_settingsViewController.smoothedSpectrogramEnabled;
    _topPeaksView.hidden = !_settingsViewController.peaksEnabled;
    _bottomPeaksView.hidden = !_settingsViewController.peaksEnabled;

    __weak PeakInspectorViewController* wself = self;
    _settingsViewController.didChangeTimings = ^(NSUInteger windowSize, double hopFraction) {
        PeakInspectorViewController* sself = wself;
        sself->_params.spectrogram.windowSizeLog2 = std::round(std::log2(windowSize));
        sself->_params.spectrogram.hopFraction = hopFraction;
        [sself initializeSourceGraph];
        [wself updateWindowView];
        [wself renderReference];
    };
    _settingsViewController.didChangeSmoothWidthBlock = ^(NSUInteger smoothWidth) {
        [wself initializeSourceGraph];
        [wself renderReference];
    };
    _settingsViewController.didChangePeaksMinSlopeBlock = ^(double slope) {
        [wself initializeSourceGraph];
        [wself renderReference];
    };
    _settingsViewController.didChangePeakWidthBlock = ^(double width) {
        PeakInspectorViewController* sself = wself;
        sself->_params.peakWidth = width;
        wself.topPeaksView.peakWidth = std::max(1.0, _params.peakWidth / _params.spectrogram.baseFrequency());
        wself.bottomPeaksView.peakWidth = std::max(1.0, _params.peakWidth / _params.spectrogram.baseFrequency());
        wself.topMidiView.peakWidth = std::max(1.0, _params.peakWidth / _params.spectrogram.baseFrequency());
        wself.bottomMidiView.peakWidth = std::max(1.0, _params.peakWidth / _params.spectrogram.baseFrequency());

        [wself initializeSourceGraph];
        [wself renderReference];
    };
    _settingsViewController.didChangeDisplaySpectrogram = ^(BOOL display) {
        wself.topSpectrogramView.hidden = !display;
        wself.bottomSpectrogramView.hidden = !display;
    };
    _settingsViewController.didChangeDisplaySmoothedSpectrogram = ^(BOOL display) {
        wself.topSmoothedView.hidden = !display;
        wself.bottomSmoothedView.hidden = !display;
    };
    _settingsViewController.didChangeDisplayPeaks = ^(BOOL display) {
        wself.topPeaksView.hidden = !display;
        wself.bottomPeaksView.hidden = !display;
    };
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
    if (!self.referenceFilePath)
        return;

    const auto& sgParams = _params.spectrogram;
    const auto sliceSize = sgParams.sliceSize();

    _referenceSpectrogramData = Spectrogram::generateFromData(std::begin(_input) + _frameOffset, sgParams.inputSize(1), sgParams, true);
    if (_referenceSpectrogramData.sliceCount == 0)
        return;

    _bottomSpectrogramView.baseFrequency = sgParams.baseFrequency();
    [_bottomSpectrogramView setData:std::begin(_referenceSpectrogramData.magnitudes)
                        frequencies:std::begin(_referenceSpectrogramData.frequencies)
                              count:sliceSize];

    [_bottomPeaksView setData:std::begin(_referenceSpectrogramData.peaks) frequencies:NULL count:sliceSize];
    [_bottomSmoothedView setData:std::begin(_referenceSpectrogramData.magnitudes) frequencies:NULL count:sliceSize];

    //[self renderMIDI];
}

- (void)renderSource {
    const auto& sgParams = _params.spectrogram;
    const auto sliceSize = sgParams.sliceSize();

    if (!_sourceSpectrogram || !_sourceSpectrogram->render())
        return;

    _topSpectrogramView.baseFrequency = _params.spectrogram.baseFrequency();
    [_topSpectrogramView setData:std::begin(_sourceSpectrogram->magnitudes())
                     frequencies:std::begin(_sourceSpectrogram->frequencies())
                           count:sliceSize];

    [_topPeaksView setData:std::begin(_sourceSpectrogram->peaks()) frequencies:NULL count:sliceSize];
    [_bottomPeaksView setMatchData:std::begin(_sourceSpectrogram->peaks()) count:sliceSize];

    [_topSmoothedView setData:std::begin(_sourceSpectrogram->magnitudes()) frequencies:NULL count:sliceSize];

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

- (IBAction)openSettings:(UIButton*)sender {
    _settingsViewController.preferredContentSize = CGSizeMake(600, 290);
    [self presentViewController:_settingsViewController animated:YES completion:nil];

    UIPopoverPresentationController *presentationController = [_settingsViewController popoverPresentationController];
    presentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    presentationController.sourceView = self.view;
    presentationController.sourceRect = sender.frame;
}

- (void)loadFile:(NSString*)file {
    self.referenceFilePath = file;

    if (file) {
        ReadFromFileModule reader{self.referenceFilePath.UTF8String};
        _input.resize(reader.availableSize());
        reader.render(std::begin(_input), _input.size());

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
    CGFloat windowWidth = (CGFloat)_params.spectrogram.windowSize() / (CGFloat)_waveformView.samplesPerPoint;
    UIEdgeInsets insets = UIEdgeInsetsZero;
    insets.left = (_windowView.bounds.size.width - windowWidth) / 2;
    insets.right = (_windowView.bounds.size.width - windowWidth) / 2;;

    _waveformView.contentInset = insets;
    _windowWidthConstraint.constant = windowWidth;
    [_windowView setNeedsLayout];
}

- (void)initializeSourceGraph {
    const auto& sgParams = _params.spectrogram;
    _sourceSpectrogram.reset(new Spectrogram{sgParams});

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

    __weak PeakInspectorViewController* wself = self;
    _microphone = dynamic_cast<MicrophoneModule*>(_sourceSpectrogram->graph().source()->module.get());
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
