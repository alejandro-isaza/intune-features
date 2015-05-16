//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "FFTSettingsViewController.h"

static NSString* const kWindowSizeKey = @"WindowSizeKey";
static NSString* const kHopFractionKey = @"HopFractionKey";
static NSString* const kDecibelGroundKey = @"DecibelGroundKey";
static NSString* const kPeakSlopeCurveMaxKey = @"PeakSlopeCurveMax";
static NSString* const kPeakSlopeCurveWidthKey = @"PeakSlopeCurveWidth";
static NSString* const kPeakWidthKey = @"PeakWidth";
static NSString* const kSmoothWidthKey = @"SmoothWidth";
static NSString* const kSpectrogramEnabledKey = @"SpectrogramEnabled";
static NSString* const kSmoothedSpectrogramEnabledKey = @"SmoothedSpectrogramEnabled";
static NSString* const kPeaksEnabledKey = @"PeaksEnabled";


@interface FFTSettingsViewController ()

@property(nonatomic, weak) IBOutlet UISlider* windowSlider;
@property(nonatomic, weak) IBOutlet UISlider* hopSlider;
@property(nonatomic, weak) IBOutlet UISlider* groundSlider;
@property(nonatomic, weak) IBOutlet UISlider* smoothWidthSlider;
@property(nonatomic, weak) IBOutlet UISlider* peakSlopeCurveMaxSlider;
@property(nonatomic, weak) IBOutlet UISlider* peakSlopeCurveWidthSlider;
@property(nonatomic, weak) IBOutlet UISlider* peakWidthSlider;
@property(nonatomic, weak) IBOutlet UITextField* windowTextField;
@property(nonatomic, weak) IBOutlet UITextField* hopTextField;
@property(nonatomic, weak) IBOutlet UITextField* groundTextField;
@property(nonatomic, weak) IBOutlet UITextField* smoothWidthTextField;
@property(nonatomic, weak) IBOutlet UITextField* peakSlopeCurveMaxTextField;
@property(nonatomic, weak) IBOutlet UITextField* peakSlopeCurveWidthTextField;
@property(nonatomic, weak) IBOutlet UITextField* peakWidthTextField;
@property(nonatomic, weak) IBOutlet UISwitch* spectrogramSwitch;
@property(nonatomic, weak) IBOutlet UISwitch* smoothedSwitch;
@property(nonatomic, weak) IBOutlet UISwitch* peaksSwitch;

@property(nonatomic) NSUInteger windowSize;
@property(nonatomic) double hopFraction;
@property(nonatomic) double decibelGround;
@property(nonatomic) double sampleRate;
@property(nonatomic) double peakSlopeCurveMax;
@property(nonatomic) double peakSlopeCurveWidth;
@property(nonatomic) double peakWidth;
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
    _peakSlopeCurveMaxSlider.value = _peakSlopeCurveMax;
    _peakSlopeCurveWidthSlider.value = _peakSlopeCurveWidth;
    _peakWidthSlider.value = _peakWidth;
    _spectrogramSwitch.on = _spectrogramEnabled;
    _smoothedSwitch.on = _smoothedSpectrogramEnabled;
    _peaksSwitch.on = _peaksEnabled;

    _windowTextField.text = [NSString stringWithFormat:@"%dfr (%.0fms)", (int)_windowSize, 1000.0 * _windowSize / _sampleRate];
    _hopTextField.text = [NSString stringWithFormat:@"%.0fms", 1000.0 * _hopFraction * _windowSize / _sampleRate];
    _groundTextField.text = [NSString stringWithFormat:@"%.0fdB", _decibelGround];
    _smoothWidthTextField.text = [NSString stringWithFormat:@"%d frames", (int)_smoothWidth];
    _peakSlopeCurveMaxTextField.text = [NSString stringWithFormat:@"%f", _peakSlopeCurveMax];
    _peakSlopeCurveWidthTextField.text = [NSString stringWithFormat:@"%f", _peakSlopeCurveWidth];
    _peakWidthTextField.text = [NSString stringWithFormat:@"%f Hz", _peakWidth];
}

- (void)loadPreferences {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    _windowSize = [self preferenceForKey:kWindowSizeKey defaultValue:1024];
    _hopFraction = [self preferenceForKey:kHopFractionKey defaultValue:0.5];
    _decibelGround = [self preferenceForKey:kDecibelGroundKey defaultValue:-100.0];
    _peakSlopeCurveMax = [self preferenceForKey:kPeakSlopeCurveMaxKey defaultValue:0.3];
    _peakSlopeCurveWidth = [self preferenceForKey:kPeakSlopeCurveWidthKey defaultValue:5000];
    _peakWidth = [self preferenceForKey:kPeakWidthKey defaultValue:1];

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
    [defaults setDouble:_peakSlopeCurveMax forKey:kPeakSlopeCurveMaxKey];
    [defaults setDouble:_peakSlopeCurveWidth forKey:kPeakSlopeCurveWidthKey];
    [defaults setDouble:_peakWidth forKey:kPeakWidthKey];
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

- (IBAction)updatePeakSlopeCurveMax {
    _peakSlopeCurveMax = _peakSlopeCurveMaxSlider.value;
    _peakSlopeCurveMaxTextField.text = [NSString stringWithFormat:@"%f", _peakSlopeCurveMax];
}

- (IBAction)updatePeakSlopeCurveWidth {
    _peakSlopeCurveWidth = _peakSlopeCurveWidthSlider.value;
    _peakSlopeCurveWidthTextField.text = [NSString stringWithFormat:@"%f", _peakSlopeCurveWidth];
}

- (IBAction)updatePeakWidth {
    _peakWidth = _peakWidthSlider.value;
    _peakWidthTextField.text = [NSString stringWithFormat:@"%f Hz", _peakWidth];
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

- (IBAction)didChangePeakSlopeCurveMax {
    if (_didChangePeakSlopeCurveMaxBlock)
        _didChangePeakSlopeCurveMaxBlock(_peakSlopeCurveMax);
    [self savePreferences];
}

- (IBAction)didChangePeakSlopeCurveWidth {
    if (_didChangePeakSlopeCurveWidthBlock)
        _didChangePeakSlopeCurveWidthBlock(_peakSlopeCurveWidth);
    [self savePreferences];
}

- (IBAction)didChangePeakWidth {
    if (_didChangePeakWidthBlock)
        _didChangePeakWidthBlock(_peakWidth);
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
