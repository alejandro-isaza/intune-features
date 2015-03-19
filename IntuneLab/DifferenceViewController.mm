//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "DifferenceViewController.h"
#import "IntuneLab-Swift.h"

#import "VMSpectrogramViewController.h"
#import "VMFilePickerController.h"
#import "FFTSettingsViewController.h"

@interface DifferenceViewController ()

@property(nonatomic, strong) VMSpectrogramViewController *spectrogramViewControllerTop;
@property(nonatomic, strong) VMSpectrogramViewController *spectrogramViewControllerBottom;
@property(nonatomic, weak) IBOutlet UIView *spectrogramViewContainerTop;
@property(nonatomic, weak) IBOutlet UIView *spectrogramViewContainerBottom;
@property(nonatomic, strong) FFTSettingsViewController *settingsViewController;

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

    [_spectrogramViewControllerTop setWindowTime:_settingsViewController.windowTime
                                         hopTime:_settingsViewController.hopTime];
    [_spectrogramViewControllerBottom setWindowTime:_settingsViewController.windowTime
                                            hopTime:_settingsViewController.hopTime];
}

- (void)calculateDifference {
    void* topData = nullptr;
    [_spectrogramViewControllerTop getData:&topData count:nil];

    void* bottomData = nullptr;
    [_spectrogramViewControllerBottom getData:&bottomData count:nil];

    /*
     [_distanceView setSamplesA:topData count:count offset:offset];
     [_distanceView setSamplesB:topData count:count offset:offset];
     [_distanceView calculateDifference];
     */
}

- (IBAction)openSettings:(UIButton*)sender {
    [self presentViewController:_settingsViewController animated:YES completion:nil];

    UIPopoverPresentationController *presentationController = [_settingsViewController popoverPresentationController];
    presentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    presentationController.sourceView = self.view;
    presentationController.sourceRect = sender.frame;
}



@end
