//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "PeakInspectorViewController.h"
#import "IntuneLab-Swift.h"

#import "FFTSettingsViewController.h"
#import "VMFilePickerController.h"
#import "VMFileLoader.h"

#include <tempo/algorithms/NoteTracker.h>
#include <tempo/algorithms/Spectrogram.h>
#include <tempo/modules/Buffering.h>
#include <tempo/modules/Converter.h>
#include <tempo/modules/Gain.h>
#include <tempo/modules/Splitter.h>
#include <tempo/modules/MicrophoneModule.h>

using namespace tempo;
using ReferenceDataType = VMFileLoaderDataType;
using SourceDataType = Spectrogram::DataType;


static const NSTimeInterval kWaveformDuration = 1;
static const float kSampleRate = 44100;
static const SourceDataType kGainValue = 4.0;

@interface PeakInspectorViewController ()  <UIScrollViewDelegate>

@property(nonatomic, strong) VMFileLoader* fileLoader;

@property(nonatomic, weak) IBOutlet UIView* topContainerView;
@property(nonatomic, weak) IBOutlet UIView* bottomContainerView;
@property(nonatomic, weak) IBOutlet UIView* waveformContainerView;
@property(nonatomic, weak) IBOutlet UIView* windowView;
@property(nonatomic, weak) IBOutlet UILabel* notesLabel;

@property(nonatomic, strong) VMFrequencyView* topSpectrogramView;
@property(nonatomic, strong) VMFrequencyView* topPeaksView;
@property(nonatomic, strong) VMFrequencyView* bottomSpectrogramView;
@property(nonatomic, strong) VMFrequencyView* bottomPeaksView;
@property(nonatomic, strong) VMWaveformView* waveformView;
@property(nonatomic, strong) FFTSettingsViewController *settingsViewController;
@property(nonatomic, assign) NSUInteger frameOffset;

@property(nonatomic) std::shared_ptr<MicrophoneModule> microphone;
@property(nonatomic) std::shared_ptr<Converter<MicrophoneModule::DataType, SourceDataType>> converter;
@property(nonatomic) std::shared_ptr<Buffering<SourceDataType>> buffering;
@property(nonatomic) std::shared_ptr<Gain<SourceDataType>> gain;
@property(nonatomic) std::shared_ptr<Splitter<SourceDataType>> splitter;
@property(nonatomic) std::shared_ptr<Spectrogram> sourceSpectrogram;
@property(nonatomic) std::shared_ptr<Spectrogram> sourcePeaks;
@property(nonatomic) std::shared_ptr<NoteTracker> noteTracker;

@end

@implementation PeakInspectorViewController {
    tempo::Spectrogram::Parameters _params;

    tempo::UniqueBuffer<ReferenceDataType> _peakData;
    tempo::UniqueBuffer<ReferenceDataType> _spectrogramData;

    tempo::UniqueBuffer<SourceDataType> _sourcePeakData;
    tempo::UniqueBuffer<SourceDataType> _sourceSpectrogramData;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _topSpectrogramView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _bottomSpectrogramView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _topPeaksView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];
    _bottomPeaksView = [[VMFrequencyView alloc] initWithFrame:CGRectZero];

    [self loadContainerView:_topContainerView spectrogram:_topSpectrogramView peaks:_topPeaksView];
    [self loadContainerView:_bottomContainerView spectrogram:_bottomSpectrogramView peaks:_bottomPeaksView];
    [self loadWaveformView];
    [self loadSettings];

    NSString* file = [[NSBundle mainBundle] pathForResource:[@"Audio" stringByAppendingPathComponent:@"twinkle_twinkle.xml"] ofType:@"caf"];
    [self loadFile:file];

    [self initializeSourceGraph];
    _microphone->start();
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateWindowView];
}

- (void)loadContainerView:(UIView*)containerView spectrogram:(VMFrequencyView*)spectrogramView peaks:(VMFrequencyView*)peaksView {
    peaksView.frame = containerView.bounds;
    peaksView.translatesAutoresizingMaskIntoConstraints = NO;
    peaksView.backgroundColor = [UIColor clearColor];
    peaksView.lineColor = [UIColor redColor];
    peaksView.peaks = YES;
    [containerView addSubview:peaksView];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{@"view": peaksView}]];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{@"view": peaksView}]];

    spectrogramView.frame = containerView.bounds;
    spectrogramView.translatesAutoresizingMaskIntoConstraints = NO;
    spectrogramView.backgroundColor = [UIColor clearColor];
    spectrogramView.lineColor = [UIColor blueColor];
    [containerView addSubview:spectrogramView];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{@"view": spectrogramView}]];
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{@"view": spectrogramView}]];
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

    _params.sampleRate = kSampleRate;
    _params.windowSizeLog2 = std::round(std::log2(_settingsViewController.windowSize));
    _params.hopFraction = _settingsViewController.hopFraction;
    [self updateWindowView];

    __weak PeakInspectorViewController* wself = self;
    _settingsViewController.didChangeTimings = ^(NSUInteger windowSize, double hopFraction) {
        PeakInspectorViewController* sself = wself;
        sself->_params.windowSizeLog2 = std::round(std::log2(windowSize));
        sself->_params.hopFraction = hopFraction;
        [sself initializeSourceGraph];
        sself->_microphone->start();
        [wself updateWindowView];
        [wself renderReference];
    };
}

- (void)renderReference {
    _spectrogramData = tempo::Spectrogram::generateFromData(self.fileLoader.audioData.data() + _frameOffset, _params.windowSize(), _params, false);
    [_bottomSpectrogramView setData:_spectrogramData.data() count:_spectrogramData.capacity()];

    tempo::Spectrogram::Parameters params = _params;
    params.peaks = true;
    _peakData = tempo::Spectrogram::generateFromData(self.fileLoader.audioData.data() + _frameOffset, _params.windowSize(), params, false);
    [_bottomPeaksView setData:_peakData.data() count:_peakData.capacity()];
}

- (void)renderSource {
    const auto sliceSize = _params.sliceSize();

    if (_sourceSpectrogramData.capacity() != sliceSize)
        _sourceSpectrogramData.reset(sliceSize);
    if (_sourcePeakData.capacity() != sliceSize)
        _sourcePeakData.reset(sliceSize);

    auto sourceSize = _sourceSpectrogram->render(_sourceSpectrogramData);
    if (sourceSize != 0)
        [_topSpectrogramView setData:_sourceSpectrogramData.data() count:sourceSize];

    auto peaksSize = _sourcePeaks->render(_sourcePeakData);
    if (peaksSize != 0) {
        [_topPeaksView setData:_sourcePeakData.data() count:peaksSize];
        [_bottomPeaksView setMatchData:_sourcePeakData.data() count:_sourcePeakData.capacity()];
    }

    NSMutableString* labelText = [NSMutableString string];
    auto notes = _noteTracker->matchOnNotes();
    for (auto& item : notes) {
        [labelText appendFormat:@"%d(%d)", item.first, (int)item.second.count()];
    }
    self.notesLabel.text = labelText;
}

- (IBAction)openFile:(UIButton*)sender {
    VMFilePickerController *filePicker = [[VMFilePickerController alloc] init];
    filePicker.selectionBlock = ^(NSString* file, NSString* filename) {
        [self loadFile:file];
    };
    [filePicker presentInViewController:self sourceRect:sender.frame];
}

- (IBAction)openSettings:(UIButton*)sender {
    _microphone->stop();

    // Sleep to allow _microphone->onDataAvailable() to return
    usleep(1000);

    [self presentViewController:_settingsViewController animated:YES completion:nil];

    UIPopoverPresentationController *presentationController = [_settingsViewController popoverPresentationController];
    presentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    presentationController.sourceView = self.view;
    presentationController.sourceRect = sender.frame;
}

- (void)loadFile:(NSString*)file {
    self.fileLoader = [VMFileLoader fileLoaderWithPath:file];
    [self.fileLoader loadAudioData:^(const tempo::Buffer<double>& buffer) {
        [self.waveformView setSamples:buffer.data() count:buffer.capacity()];
        [self renderReference];
    }];

    if (file) {
        _noteTracker->setReferenceFile([file UTF8String]);
        NSString* annotationsFile = [VMFilePickerController annotationsForFilePath:file];
        if (annotationsFile)
            _noteTracker->setReferenceAnnotationsFile([annotationsFile UTF8String]);
    }
}

- (void)updateWindowView {
    CGRect frame = _windowView.frame;
    frame.size.width = (CGFloat)_params.windowSize() / (CGFloat)_waveformView.samplesPerPoint;
    _windowView.frame = frame;
}

- (void)initializeSourceGraph {
    _microphone.reset(new MicrophoneModule);
    _converter.reset(new Converter<MicrophoneModule::DataType, SourceDataType>);
    _buffering.reset(new Buffering<SourceDataType>(_params.windowSize()));
    _gain.reset(new Gain<SourceDataType>(kGainValue));
    _splitter.reset(new Splitter<SourceDataType>());
    _microphone >> _converter >> _buffering >> _gain >> _splitter;

    auto params = _params;
    _sourceSpectrogram.reset(new Spectrogram(params, _splitter));
    _splitter->addNode();

    params.peaks = true;
    _sourcePeaks.reset(new Spectrogram(params, _splitter));
    _splitter->addNode();

    // Set up note tracker
    _noteTracker.reset(new NoteTracker);
    auto noteTrackerParams = _noteTracker->parameters();
    noteTrackerParams.spectrogram = _params;
    _noteTracker->setParameters(noteTrackerParams);
    _noteTracker->setSource(_splitter);
    _splitter->addNode();
    if (self.fileLoader) {
        _noteTracker->setReferenceFile([self.fileLoader.filePath UTF8String]);
        NSString* annotationsFile = [VMFilePickerController annotationsForFilePath:self.fileLoader.filePath];
        if (annotationsFile)
            _noteTracker->setReferenceAnnotationsFile([annotationsFile UTF8String]);
    }

    __weak PeakInspectorViewController* wself = self;
    _microphone->onDataAvailable([wself](std::size_t size) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [wself renderSource];
        });
    });
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!self.fileLoader)
        return;

    _frameOffset = _waveformView.startFrame;
    [self renderReference];
}

@end

