//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

@interface FFTSettingsViewController : UIViewController

+ (instancetype)createWithSampleRate:(double)sampleRate;

@property(nonatomic, readonly) NSUInteger windowSize;
@property(nonatomic, readonly) double hopFraction;
@property(nonatomic, readonly) double decibelGround;

@property (nonatomic, copy) void (^didChangeTimings)(NSUInteger, double);
@property (nonatomic, copy) void (^didChangeDecibelGround)(double);

@end
