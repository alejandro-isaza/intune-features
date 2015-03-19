//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "DifferenceViewController.h"
#import "IntuneLab-Swift.h"

#import "VMSpectrogramViewController.h"
#import "VMFilePickerController.h"

@interface DifferenceViewController ()

@property(nonatomic, strong) VMSpectrogramViewController *spectrogramViewControllerTop;
@property(nonatomic, strong) VMSpectrogramViewController *spectrogramViewControllerBottom;
@property(nonatomic, weak) IBOutlet UIView *spectrogramViewContainerTop;
@property(nonatomic, weak) IBOutlet UIView *spectrogramViewContainerBottom;

@end

@implementation DifferenceViewController

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
    _spectrogramViewControllerBottom.spectrogramHighColor = [UIColor greenColor];

    // setup did scroll blocks
    __weak DifferenceViewController* wself = self;
    __weak VMSpectrogramViewController* wbottom = _spectrogramViewControllerBottom;
    _spectrogramViewControllerTop.didScrollBlock = ^(CGFloat dx) {
        [wbottom scrollBy:dx];
        [wself calculateDifference];
    };
    _spectrogramViewControllerBottom.didScrollBlock = ^(CGFloat dx) {
        [wself calculateDifference];
    };
}

- (void)calculateDifference {
    DataType* topData = nullptr;
    [_spectrogramViewControllerTop getData:&topData count:nil];

    DataType* bottomData = nullptr;
    [_spectrogramViewControllerBottom getData:&bottomData count:nil];

    /*
     [_distanceView setSamplesA:topData count:count offset:offset];
     [_distanceView setSamplesB:topData count:count offset:offset];
     [_distanceView calculateDifference];
     */
}


@end
