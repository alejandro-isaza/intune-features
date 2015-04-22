//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTSettingsViewController.h"

static NSString* const kWindowSizeKey = @"WindowSizeKey";
static NSString* const kHopFractionKey = @"HopFractionKey";
static NSString* const kDecibelGroundKey = @"DecibelGroundKey";
static NSString* const kSmoothWidthKey = @"SmoothWidth";
static NSString* const kSpectrogramEnabledKey = @"SpectrogramEnabled";
static NSString* const kSmoothedSpectrogramEnabledKey = @"SmoothedSpectrogramEnabled";
static NSString* const kPeaksEnabledKey = @"PeaksEnabled";


@interface FFTSettingsViewController ()

@property(nonatomic, weak) IBOutlet UISlider* windowSlider;
@property(nonatomic, weak) IBOutlet UISlider* hopSlider;
@property(nonatomic, weak) IBOutlet UISlider* groundSlider;
@property(nonatomic, weak) IBOutlet UISlider* smoothWidthSlider;
@property(nonatomic, weak) IBOutlet UITextField* windowTextField;
@property(nonatomic, weak) IBOutlet UITextField* hopTextField;
@property(nonatomic, weak) IBOutlet UITextField* groundTextField;
@property(nonatomic, weak) IBOutlet UITextField* smoothWidthTextField;
@property(nonatomic, weak) IBOutlet UISwitch* spectrogramSwitch;
@property(nonatomic, weak) IBOutlet UISwitch* smoothedSwitch;
@property(nonatomic, weak) IBOutlet UISwitch* peaksSwitch;

@property(nonatomic) NSUInteger windowSize;
@property(nonatomic) double hopFraction;
@property(nonatomic) double decibelGround;
@property(nonatomic) double sampleRate;
@property(nonatomic) NSUInteger smoothWidth;
@property(nonatomic) BOOL spectrogramEnabled;
@property(nonatomic) BOOL smoothedSpectrogramEnabled;
@property(nonatomic) BOOL peaksEnabled;

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

    _windowSlider.value = log2(_windowSize);
    _hopSlider.value = _hopFraction;
    _groundSlider.value = _decibelGround;
    _smoothWidthSlider.value = _smoothWidth;
    _spectrogramSwitch.on = _spectrogramEnabled;
    _smoothedSwitch.on = _smoothedSpectrogramEnabled;
    _peaksSwitch.on = _peaksEnabled;

    _windowTextField.text = [NSString stringWithFormat:@"%dfr (%.0fms)", (int)_windowSize, 1000.0 * _windowSize / _sampleRate];
    _hopTextField.text = [NSString stringWithFormat:@"%.0fms", 1000.0 * _hopFraction * _windowSize / _sampleRate];
    _groundTextField.text = [NSString stringWithFormat:@"%.0fdB", _decibelGround];
    _smoothWidthTextField.text = [NSString stringWithFormat:@"%d frames", (int)_smoothWidth];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (_didChangeTimings)
        _didChangeTimings(_windowSize, _hopFraction);
}

- (void)loadPreferences {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    _windowSize = [self preferenceForKey:kWindowSizeKey defaultValue:1024];
    _hopFraction = [self preferenceForKey:kHopFractionKey defaultValue:0.5];
    _decibelGround = [self preferenceForKey:kDecibelGroundKey defaultValue:-100.0];

    if ([defaults objectForKey:kSmoothWidthKey])
        _smoothWidth = [defaults integerForKey:kSmoothWidthKey];

    if ([defaults objectForKey:kSpectrogramEnabledKey])
        _spectrogramEnabled = [defaults boolForKey:kSpectrogramEnabledKey];
    if ([defaults objectForKey:kSmoothedSpectrogramEnabledKey])
        _smoothedSpectrogramEnabled = [defaults boolForKey:kSmoothedSpectrogramEnabledKey];
    if ([defaults objectForKey:kPeaksEnabledKey])
        _peaksEnabled = [defaults boolForKey:kPeaksEnabledKey];
}

- (void)savePreferences {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:_windowSize forKey:kWindowSizeKey];
    [defaults setDouble:_hopFraction forKey:kHopFractionKey];
    [defaults setDouble:_decibelGround forKey:kDecibelGroundKey];
    [defaults setInteger:_smoothWidth forKey:kSmoothWidthKey];
    [defaults setBool:_spectrogramEnabled forKey:kSpectrogramEnabledKey];
    [defaults setBool:_smoothedSpectrogramEnabled forKey:kSmoothedSpectrogramEnabledKey];
    [defaults setBool:_peaksEnabled forKey:kPeaksEnabledKey];
    [defaults synchronize];
}

- (double)preferenceForKey:(NSString*)key defaultValue:(double)defaultValue {
    double value = defaultValue;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:key])
        value = [defaults doubleForKey:key];

    return value;
}

- (IBAction)updateWindow {
    _windowSize = exp2(round(_windowSlider.value));
    _hopFraction = _hopSlider.value;
    _windowTextField.text = [NSString stringWithFormat:@"%dfr (%.0fms)", (int)_windowSize, 1000.0 * _windowSize / _sampleRate];
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

- (IBAction)updateSmoothWidth {
    _smoothWidth = _smoothWidthSlider.value;
    _smoothWidthTextField.text = [NSString stringWithFormat:@"%d frames", (int)_smoothWidth];
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

- (IBAction)didChangeSmoothWidth {
    if (_didChangeSmoothWidthBlock)
        _didChangeSmoothWidthBlock(_smoothWidth);
    [self savePreferences];
}

- (IBAction)didChangeSpectrogram {
    _spectrogramEnabled = _spectrogramSwitch.on;
    if (_didChangeDisplaySpectrogram)
        _didChangeDisplaySpectrogram(_spectrogramEnabled);
    [self savePreferences];
}

- (IBAction)didChangeSmoothed {
    _smoothedSpectrogramEnabled = _smoothedSwitch.on;
    if (_didChangeDisplaySmoothedSpectrogram)
        _didChangeDisplaySmoothedSpectrogram(_smoothedSpectrogramEnabled);
    [self savePreferences];
}

- (IBAction)didChangePeaks {
    _peaksEnabled = _peaksSwitch.on;
    if (_didChangeDisplayPeaks)
        _didChangeDisplayPeaks(_peaksEnabled);
    [self savePreferences];
}

@end
