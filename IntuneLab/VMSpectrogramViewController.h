//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

#include <tempo/modules/ReadFromFileModule.h>

using namespace tempo;
using DataType = ReadFromFileModule::DataType;
using SizeType = SourceModule<DataType>::SizeType;

@interface VMSpectrogramViewController : UIViewController

@property(nonatomic) NSTimeInterval windowTime;
@property(nonatomic) NSTimeInterval hopTime;
@property(nonatomic, strong) UIColor* spectrogramHighColor;
@property(nonatomic, strong) UIColor* spectrogramLowColor;
@property(nonatomic, copy) void (^didScrollBlock)(CGFloat dx);

+ (instancetype)create;

- (void)getData:(DataType**)data count:(NSInteger*)count;
- (void)scrollBy:(CGFloat)dx;

@end
