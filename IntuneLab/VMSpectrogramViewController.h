//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

#include <tempo/modules/ReadFromFileModule.h>


@interface VMSpectrogramViewController : UIViewController

@property(nonatomic, readonly) NSTimeInterval windowTime;
@property(nonatomic, readonly) NSTimeInterval hopTime;
@property(nonatomic) double decibelGround;
@property(nonatomic, strong) UIColor* spectrogramHighColor;
@property(nonatomic, strong) UIColor* spectrogramLowColor;
@property(nonatomic, copy) void (^didScrollBlock)(CGFloat dx);

+ (instancetype)create;

- (void)setWindowTime:(NSTimeInterval)windowTime hopTime:(NSTimeInterval)hopTime;
- (void)getData:(void**)data count:(NSInteger*)count;
- (void)scrollBy:(CGFloat)dx;

@end
