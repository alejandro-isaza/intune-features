//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTSettingsViewController.h"

static NSString* const kWindowSizeKey = @"WindowSizeKey";
static NSString* const kHopFractionKey = @"HopFractionKey";
static NSString* const kDecibelGroundKey = @"DecibelGroundKey";


@interface FFTSettingsViewController ()

@property(nonatomic, weak) IBOutlet UISlider* windowSlider;
@property(nonatomic, weak) IBOutlet UISlider* hopSlider;
@property(nonatomic, weak) IBOutlet UISlider* groundSlider;
@property(nonatomic, weak) IBOutlet UITextField* windowTextField;
@property(nonatomic, weak) IBOutlet UITextField* hopTextField;
@property(nonatomic, weak) IBOutlet UITextField* groundTextField;

@property(nonatomic) NSUInteger windowSize;
@property(nonatomic) double hopFraction;
@property(nonatomic) double decibelGround;
@property(nonatomic) double sampleRate;

@end


@implementation FFTSettingsViewController

+ (instancetype)createWithSampleRate:(double)sampleRate {
    FFTSettingsViewController* settingsViewController = [[FFTSettingsViewController alloc] initWithNibName:@"FFTSettingsViewController" bundle:nil];
    settingsViewController.sampleRate = sampleRate;
    return settingsViewController;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self)
        return nil;

    [self loadPreferences];

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _windowSlider.value = _windowSize;
    _hopSlider.value = _hopFraction;
    _groundSlider.value = _decibelGround;

    _windowTextField.text = [NSString stringWithFormat:@"%.0fms", 1000.0 * _windowSize / _sampleRate];
    _hopTextField.text = [NSString stringWithFormat:@"%.0fms", 1000.0 * _hopFraction * _windowSize / _sampleRate];
    _groundTextField.text = [NSString stringWithFormat:@"%.0fdB", _decibelGround];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (_didChangeTimings)
        _didChangeTimings(_windowSize, _hopFraction);
}

- (void)loadPreferences {
    _windowSize = [self preferenceForKey:kWindowSizeKey defaultValue:1024];
    _hopFraction = [self preferenceForKey:kHopFractionKey defaultValue:0.5];
    _decibelGround = [self preferenceForKey:kDecibelGroundKey defaultValue:-100.0];
}

- (void)savePreferences {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:_windowSize forKey:kWindowSizeKey];
    [defaults setDouble:_hopFraction forKey:kHopFractionKey];
    [defaults setDouble:_decibelGround forKey:kDecibelGroundKey];
    [defaults synchronize];
}

- (double)preferenceForKey:(NSString*)key defaultValue:(double)defaultValue {
    double value = defaultValue;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:key])
        value = [defaults doubleForKey:key];

    return value;
}

- (void)saveDefaults {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:_windowSize forKey:kWindowSizeKey];
    [defaults setDouble:_hopFraction forKey:kHopFractionKey];
    [defaults setDouble:_decibelGround forKey:kDecibelGroundKey];
}

- (IBAction)updateWindow {
    _windowSize = exp2(round(log2(_windowSlider.value)));
    _hopFraction = _hopSlider.value;
    _windowTextField.text = [NSString stringWithFormat:@"%.0fms", 1000.0 * _windowSize / _sampleRate];
    _hopTextField.text = [NSString stringWithFormat:@"%.0fms", 1000.0 * _hopFraction * _windowSize / _sampleRate];
}

- (IBAction)updateHop {
    _hopFraction = _hopSlider.value;
    if (_hopFraction == 0)
        _hopFraction = 1 / _windowSize;
    _hopTextField.text = [NSString stringWithFormat:@"%.0fms", 1000.0 * _hopFraction * _windowSize / _sampleRate];
}

- (IBAction)updateGround {
    _decibelGround = _groundSlider.value;
    _groundTextField.text = [NSString stringWithFormat:@"%.0fdB", _decibelGround];
}

- (IBAction)didChangeWindow {
    if (_didChangeTimings)
        _didChangeTimings(_windowSize, _hopFraction);
    [self savePreferences];
}

- (IBAction)didChangeHop {
    if (_didChangeTimings)
        _didChangeTimings(_windowSize, _hopFraction);
    [self savePreferences];
}

- (IBAction)didChangeGround {
    if (_didChangeDecibelGround)
        _didChangeDecibelGround(_decibelGround);
    [self savePreferences];
}

@end
