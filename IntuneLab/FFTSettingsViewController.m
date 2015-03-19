//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTSettingsViewController.h"

static NSString* const kWindowTimeKey = @"WindowTimeKey";
static NSString* const kHopTimeKey = @"HopTimeKey";
static NSString* const kDecibelGroundKey = @"DecibelGroundKey";


@interface FFTSettingsViewController ()

@property(nonatomic, weak) IBOutlet UISlider* windowSlider;
@property(nonatomic, weak) IBOutlet UISlider* hopSlider;
@property(nonatomic, weak) IBOutlet UISlider* groundSlider;
@property(nonatomic, weak) IBOutlet UITextField* windowTextField;
@property(nonatomic, weak) IBOutlet UITextField* hopTextField;
@property(nonatomic, weak) IBOutlet UITextField* groundTextField;

@property(nonatomic) NSTimeInterval windowTime;
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

    _windowSlider.value = _windowTime * 1000.0;
    _hopSlider.value = _hopTime / _windowTime;
    _groundSlider.value = _decibelGround;

    _windowTextField.text = [NSString stringWithFormat:@"%.0fms", _windowTime * 1000.0];
    _hopTextField.text = [NSString stringWithFormat:@"%.0fms", _hopTime * 1000.0];
    _groundTextField.text = [NSString stringWithFormat:@"%.0fdB", _decibelGround];
}

- (void)loadPreferences {
    _windowTime = [self preferenceForKey:kWindowTimeKey defaultValue:0.1];
    _hopTime = [self preferenceForKey:kHopTimeKey defaultValue:0.05];
    _decibelGround = [self preferenceForKey:kDecibelGroundKey defaultValue:-100.0];
}

- (void)savePreferences {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:_windowTime forKey:kWindowTimeKey];
    [defaults setDouble:_hopTime forKey:kHopTimeKey];
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
    [defaults setDouble:_windowTime forKey:kWindowTimeKey];
    [defaults setDouble:_hopTime forKey:kHopTimeKey];
    [defaults setDouble:_decibelGround forKey:kDecibelGroundKey];
}

- (IBAction)updateWindow {
    _windowTime = _windowSlider.value / 1000.0;
    _hopTime = _hopSlider.value * _windowTime;
    _windowTextField.text = [NSString stringWithFormat:@"%.0fms", _windowTime * 1000.0];
    _hopTextField.text = [NSString stringWithFormat:@"%.0fms", _hopTime * 1000.0];
}

- (IBAction)updateHop {
    NSTimeInterval hopTime = _hopSlider.value * _windowTime;
    if (hopTime == 0)
        hopTime = 1.0 / _sampleRate;
    _hopTime = hopTime;
    _hopTextField.text = [NSString stringWithFormat:@"%.0fms", _hopTime * 1000.0];
}

- (IBAction)updateGround {
    _decibelGround = _groundSlider.value;
    _groundTextField.text = [NSString stringWithFormat:@"%.0fdB", _decibelGround];
}

- (IBAction)didChangeWindow {
    if (_didChangeTimings)
        _didChangeTimings(_windowTime, _hopTime);
    [self savePreferences];
}

- (IBAction)didChangeHop {
    if (_didChangeTimings)
        _didChangeTimings(_windowTime, _hopTime);
    [self savePreferences];
}

- (IBAction)didChangeGround {
    if (_didChangeDecibelGround)
        _didChangeDecibelGround(_decibelGround);
    [self savePreferences];
}

- (void)setHopTime:(NSTimeInterval)hopTime {
    _hopTime = hopTime;
    [self updateHop];
}

@end
