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
    _spectrogramViewControllerBottom.spectrogramHighColor = [UIColor purpleColor];

    // setup did scroll blocks
    __weak DifferenceViewController* wself = self;
    __weak VMSpectrogramViewController* wbottom = _spectrogramViewControllerBottom;
    _spectrogramViewControllerTop.didScrollBlock = ^(CGFloat dx) {
        [wbottom scrollBy:dx];
    };
    _spectrogramViewControllerBottom.didTapBlock = ^(CGPoint location, NSUInteger index) {;
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
    _settingsViewController.didChangeTimings = ^(NSTimeInterval windowTime, NSTimeInterval hopTime) {
        [wtop setWindowTime:windowTime hopTime:hopTime];
        [wbottom setWindowTime:windowTime hopTime:hopTime];
    };
    _settingsViewController.didChangeDecibelGround = ^(double decibelGround) {
        wtop.decibelGround = decibelGround;
        wbottom.decibelGround = decibelGround;
    };

    auto windowTime = _settingsViewController.windowTime;
    auto hopTime = _settingsViewController.hopTime;
    [_spectrogramViewControllerTop setWindowTime:windowTime hopTime:hopTime];
    [_spectrogramViewControllerBottom setWindowTime:windowTime hopTime:hopTime];
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

    DataType minDistance = DBL_MAX;
    vDSP_Length minIndex = 0;
    for (vDSP_Length t = 0; t < timeIndexCount; t += 1) {
        DataType distance;
        vDSP_distancesqD(topData + frequencyBinCount * t, 1, bottomData + frequencyBinCount * bottomIndex, 1, &distance, frequencyBinCount);
        _distances[t] = std::min(1.0, frequencyBinCount * distance);

        if (distance < minDistance) {
            minDistance = distance;
            minIndex = t;
        }
    }

    auto hopTime = _spectrogramViewControllerTop.hopTime;
    NSLog(@"Matched index %d, distance %f, walltime %f", (int)minIndex, minDistance, hopTime + hopTime * minIndex);
    [_spectrogramViewControllerTop highlightTimeIndex:minIndex];

    _distanceView.data = _distances.get();
    _distanceView.dataSize = timeIndexCount;
    [_distanceView clearMarkers];
    [_distanceView addVerticalMarkerAtIndex:minIndex color:[[UIColor blueColor] colorWithAlphaComponent:0.5]];
    [_distanceView addVerticalMarkerAtIndex:bottomIndex color:[[UIColor purpleColor] colorWithAlphaComponent:0.5]];
    [_distanceView addHorizontalMarkerAtValue:100*minDistance color:[[UIColor orangeColor] colorWithAlphaComponent:0.5]];

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
