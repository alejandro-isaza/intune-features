//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

#include <tempo/modules/ReadFromFileModule.h>


@interface VMSpectrogramViewController : UIViewController

@property(nonatomic) NSTimeInterval windowTime;
@property(nonatomic) NSTimeInterval hopTime;
@property(nonatomic, strong) UIColor* spectrogramHighColor;
@property(nonatomic, strong) UIColor* spectrogramLowColor;
@property(nonatomic, copy) void (^didScrollBlock)(CGFloat dx);

+ (instancetype)create;

- (void)getData:(void**)data count:(NSInteger*)count;
- (void)scrollBy:(CGFloat)dx;

@end
