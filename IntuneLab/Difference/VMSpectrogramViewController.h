//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

#include <tempo/modules/ReadFromFileModule.h>


@interface VMSpectrogramViewController : UIViewController

@property(nonatomic, readonly) NSUInteger windowSize;
@property(nonatomic, readonly) double hopFraction;
@property(nonatomic) double decibelGround;
@property(nonatomic, strong) UIColor* spectrogramHighColor;
@property(nonatomic, strong) UIColor* spectrogramLowColor;

@property(nonatomic, copy) void (^didScrollBlock)(CGFloat dx);
@property(nonatomic, copy) void (^didTapBlock)(CGPoint location, NSUInteger timeIndex);

@property(nonatomic, readonly) double* data;
@property(nonatomic, readonly) double* peaks;
@property(nonatomic, readonly) NSUInteger dataSize;
@property(nonatomic, readonly) NSUInteger frequencyBinCount;

+ (instancetype)create;

- (void)highlightTimeIndex:(NSUInteger)index;
- (void)setWindowSize:(NSUInteger)windowTime hopFraction:(double)hopFraction;
- (void)scrollBy:(CGFloat)dx;

@end
