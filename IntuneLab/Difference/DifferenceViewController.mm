//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "DifferenceViewController.h"
#import "IntuneLab-Swift.h"

#import "VMDistancesView.h"
#import "VMSpectrogramViewController.h"
#import "VMFilePickerController.h"
#import "FFTSettingsViewController.h"
#import <Accelerate/Accelerate.h>

using DataType = double;
using SizeType = vDSP_Length;


@interface DifferenceViewController ()

@property(nonatomic, strong) VMSpectrogramViewController *spectrogramViewControllerTop;
@property(nonatomic, strong) VMSpectrogramViewController *spectrogramViewControllerBottom;
@property(nonatomic, strong) FFTSettingsViewController *settingsViewController;
@property(nonatomic, weak) IBOutlet UIView *spectrogramViewContainerTop;
@property(nonatomic, weak) IBOutlet UIView *spectrogramViewContainerBottom;
@property(nonatomic, weak) IBOutlet UIScrollView *distanceScrollView;
@property(nonatomic, weak) IBOutlet VMDistancesView *distanceView;

@end

@implementation DifferenceViewController {
    std::unique_ptr<DataType[]> _distances;
    SizeType _distancesSize;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // create top spectrogram
    _spectrogramViewControllerTop = [VMSpectrogramViewController create];
    [self addChildViewController:_spectrogramViewControllerTop];
    _spectrogramViewControllerTop.view.frame = _spectrogramViewContainerTop.bounds;
    [_spectrogramViewContainerTop addSubview:_spectrogramViewControllerTop.view];
    [_spectrogramViewControllerTop didMoveToParentViewController:self];

    // create bottom spectrogram
    _spectrogramViewControllerBottom = [VMSpectrogramViewController create];
    [self addChildViewController:_spectrogramViewControllerBottom];
    _spectrogramViewControllerBottom.view.frame = _spectrogramViewContainerBottom.bounds;
    [_spectrogramViewContainerBottom addSubview:_spectrogramViewControllerBottom.view];
    [_spectrogramViewControllerBottom didMoveToParentViewController:self];

    // setup did scroll blocks
    __weak DifferenceViewController* wself = self;
    __weak VMSpectrogramViewController* wbottom = _spectrogramViewControllerBottom;
    _spectrogramViewControllerTop.didScrollBlock = ^(CGFloat dx) {
        [wbottom scrollBy:dx];
    };
    _spectrogramViewControllerTop.didTapBlock = ^(CGPoint location, NSUInteger index) {
        [wself.distanceView addVerticalMarkerAtIndex:index color:[[UIColor blueColor] colorWithAlphaComponent:0.5]];
    };
    _spectrogramViewControllerBottom.didTapBlock = ^(CGPoint location, NSUInteger index) {
        [wself calculateDifference:index];
    };
    
    [self initializeSettings];
}

- (void)initializeSettings {
    _settingsViewController = [FFTSettingsViewController createWithSampleRate:44100];
    _settingsViewController.modalPresentationStyle = UIModalPresentationPopover;
    _settingsViewController.preferredContentSize = CGSizeMake(600, 150);

    __weak VMSpectrogramViewController* wtop = _spectrogramViewControllerTop;
    __weak VMSpectrogramViewController* wbottom = _spectrogramViewControllerBottom;
    _settingsViewController.didChangeTimings = ^(NSUInteger windowSize, double hopFraction) {
        auto params = wtop.parameters;
        params.windowSizeLog2 = std::round(std::log2(windowSize));
        params.hopFraction = hopFraction;
        wtop.parameters = params;
        wbottom.parameters = params;
    };
    _settingsViewController.didChangeDecibelGround = ^(double decibelGround) {
        wtop.decibelGround = decibelGround;
        wbottom.decibelGround = decibelGround;
    };

    auto params = wtop.parameters;
    params.windowSizeLog2 = std::round(std::log2(_settingsViewController.windowSize));
    params.hopFraction = _settingsViewController.hopFraction;
    wtop.parameters = params;
    wbottom.parameters = params;
    wtop.decibelGround = _settingsViewController.decibelGround;
    wbottom.decibelGround = _settingsViewController.decibelGround;
}

- (void)calculateDifference:(NSUInteger)bottomIndex {
    DataType* bottomData = (DataType*)_spectrogramViewControllerBottom.data;
    DataType* topData = (DataType*)_spectrogramViewControllerTop.data;
    vDSP_Length topDataSize = _spectrogramViewControllerTop.dataSize;
    vDSP_Length frequencyBinCount = _spectrogramViewControllerTop.frequencyBinCount;
    vDSP_Length timeIndexCount = topDataSize / frequencyBinCount;

    if (timeIndexCount > _distancesSize) {
        _distances.reset(new DataType[timeIndexCount]);
        _distancesSize = timeIndexCount;
    }

    for (vDSP_Length t = 0; t < timeIndexCount; t += 1) {
        DataType distance;
        vDSP_distancesqD(topData + frequencyBinCount * t, 1, bottomData + frequencyBinCount * bottomIndex, 1, &distance, frequencyBinCount);
        _distances[t] = std::min(1.0, distance/frequencyBinCount);
    }

    // Convert to decibles
    double ref = 1.0;
    vDSP_vdbconD(_distances.get(), 1, &ref, _distances.get(), 1, timeIndexCount, 1);

    // Get average distance
    double mean;
    vDSP_measqvD(_distances.get(), 1, &mean, timeIndexCount);

    // Get minimum distance
    double min;
    vDSP_Length mini;
    vDSP_minviD(_distances.get(), 1, &min, &mini, timeIndexCount);

    [_spectrogramViewControllerTop highlightTimeIndex:mini];

    _distanceView.min = -100;
    _distanceView.max = 0;
    _distanceView.data = _distances.get();
    _distanceView.dataSize = timeIndexCount;
    [_distanceView clearMarkers];
    [_distanceView addVerticalMarkerAtIndex:mini color:[[UIColor blueColor] colorWithAlphaComponent:0.5]];
    [_distanceView addVerticalMarkerAtIndex:bottomIndex color:[[UIColor purpleColor] colorWithAlphaComponent:0.5]];
    [_distanceView addHorizontalMarkerAtValue:min color:[[UIColor orangeColor] colorWithAlphaComponent:0.5]];
    [_distanceView addHorizontalMarkerAtValue:mean color:[[UIColor greenColor] colorWithAlphaComponent:0.5]];

    CGSize size = [self.distanceView sizeThatFits:self.distanceView.bounds.size];
    self.distanceView.frame = {CGPointZero, size};
    self.distanceScrollView.contentSize = size;
    [self.distanceScrollView layoutSubviews];
}

- (IBAction)openSettings:(UIButton*)sender {
    [self presentViewController:_settingsViewController animated:YES completion:nil];

    UIPopoverPresentationController *presentationController = [_settingsViewController popoverPresentationController];
    presentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    presentationController.sourceView = self.view;
    presentationController.sourceRect = sender.frame;
}



@end
