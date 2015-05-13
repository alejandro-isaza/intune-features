//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

#include <tempo/algorithms/Spectrogram.h>


@interface VMSpectrogramViewController : UIViewController

@property(nonatomic) tempo::Spectrogram::Parameters parameters;
@property(nonatomic) double decibelGround;
@property(nonatomic, strong) UIColor* spectrogramHighColor;
@property(nonatomic, strong) UIColor* spectrogramLowColor;

@property(nonatomic, copy) void (^didScrollBlock)(CGFloat dx);
@property(nonatomic, copy) void (^didTapBlock)(CGPoint location, NSUInteger timeIndex);

@property(nonatomic, readonly) const double* data;
@property(nonatomic, readonly) const double* peaks;
@property(nonatomic, readonly) NSUInteger dataSize;
@property(nonatomic, readonly) NSUInteger frequencyBinCount;

+ (instancetype)create;

- (void)highlightTimeIndex:(NSUInteger)index;
- (void)scrollBy:(CGFloat)dx;

@end
