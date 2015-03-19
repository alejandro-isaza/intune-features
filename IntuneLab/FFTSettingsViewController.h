//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

@interface FFTSettingsViewController : UIViewController

+ (instancetype)createWithSampleRate:(double)sampleRate;

@property(nonatomic, readonly) NSTimeInterval windowTime;
@property(nonatomic) NSTimeInterval hopTime;
@property(nonatomic, readonly) double decibelGround;

@property (nonatomic, copy) void (^didChangeTimings)(NSTimeInterval, NSTimeInterval);
@property (nonatomic, copy) void (^didChangeDecibelGround)(double);

@end
