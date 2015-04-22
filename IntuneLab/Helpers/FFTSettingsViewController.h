//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

@interface FFTSettingsViewController : UIViewController

+ (instancetype)createWithSampleRate:(double)sampleRate;

@property(nonatomic, readonly) NSUInteger windowSize;
@property(nonatomic, readonly) double hopFraction;
@property(nonatomic, readonly) double decibelGround;
@property(nonatomic, readonly) NSUInteger smoothWidth;
@property(nonatomic, readonly) BOOL spectrogramEnabled;
@property(nonatomic, readonly) BOOL smoothedSpectrogramEnabled;
@property(nonatomic, readonly) BOOL peaksEnabled;

@property (nonatomic, copy) void (^didChangeTimings)(NSUInteger, double);
@property (nonatomic, copy) void (^didChangeDecibelGround)(double);
@property (nonatomic, copy) void (^didChangeSmoothWidthBlock)(NSUInteger);
@property (nonatomic, copy) void (^didChangeDisplaySpectrogram)(BOOL);
@property (nonatomic, copy) void (^didChangeDisplaySmoothedSpectrogram)(BOOL);
@property (nonatomic, copy) void (^didChangeDisplayPeaks)(BOOL);

@end
