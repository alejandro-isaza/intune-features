//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

@interface VMDistancesView : UIView

@property(nonatomic, strong) IBInspectable UIColor* foregroundColor;

@property(nonatomic) double max;
@property(nonatomic) double min;
@property(nonatomic) double* data;
@property(nonatomic) NSUInteger dataSize;

- (void)clearMarkers;
- (void)addVerticalMarkerAtIndex:(NSUInteger)index color:(UIColor*)color;
- (void)addHorizontalMarkerAtValue:(double)value color:(UIColor*)color;

@end
