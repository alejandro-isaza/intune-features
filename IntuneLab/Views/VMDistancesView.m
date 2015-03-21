//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMDistancesView.h"

@interface VMDistancesView ()

@property(nonatomic, strong) NSMutableDictionary* verticalMarkers;
@property(nonatomic, strong) NSMutableDictionary* horizontalMarkers;

@end


@implementation VMDistancesView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    _min = 0;
    _max = 1;
    _verticalMarkers = [NSMutableDictionary dictionary];
    _horizontalMarkers = [NSMutableDictionary dictionary];
    _foregroundColor = [UIColor darkGrayColor];
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    _min = 0;
    _max = 1;
    _verticalMarkers = [NSMutableDictionary dictionary];
    _horizontalMarkers = [NSMutableDictionary dictionary];
    _foregroundColor = [UIColor darkGrayColor];

    return self;
}

- (void)setData:(double *)data {
    _data = data;
    [self setNeedsDisplay];
}

- (void)setDataSize:(NSUInteger)dataSize {
    _dataSize = dataSize;
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay];
}

- (void)clearMarkers {
    [self.verticalMarkers removeAllObjects];
    [self.horizontalMarkers removeAllObjects];
    [self setNeedsDisplay];
}

- (void)addVerticalMarkerAtIndex:(NSUInteger)index color:(UIColor*)color {
    [self.verticalMarkers setObject:color forKey:@(index)];
    [self setNeedsDisplay];
}

- (void)addHorizontalMarkerAtValue:(double)value color:(UIColor*)color {
    [self.horizontalMarkers setObject:color forKey:@(value)];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    if (!_data || _dataSize == 0)
        return;

    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.foregroundColor setFill];

    __block CGRect drawRect;
    drawRect.origin.x = 0;
    drawRect.size.width = MAX(1.0, rect.size.width / _dataSize);

    for (NSUInteger i = 0; i < _dataSize; i += 1) {
        CGFloat y = [self yForValue:_data[i]];
        if (y < 1.0)
            continue;

        drawRect.origin.y = y;
        drawRect.size.height = rect.size.height - y;
        CGContextFillRect(context, drawRect);

        drawRect.origin.x += drawRect.size.width;
    }

    drawRect.origin.y = 0;
    drawRect.size.height = rect.size.height;
    [self.verticalMarkers enumerateKeysAndObjectsUsingBlock:^(NSNumber* key, UIColor* color, BOOL* stop) {
        NSUInteger index = [key unsignedIntegerValue];

        [color setFill];
        drawRect.origin.x = index * drawRect.size.width;
        CGContextFillRect(context, drawRect);
    }];

    drawRect.origin.x = 0;
    drawRect.size.height = 1;
    drawRect.size.width = rect.size.width;
    [self.horizontalMarkers enumerateKeysAndObjectsUsingBlock:^(NSNumber* number, UIColor* color, BOOL* stop) {
        [color setFill];
        drawRect.origin.y = [self yForValue:[number doubleValue]];
        CGContextFillRect(context, drawRect);
    }];
}

- (CGFloat)yForValue:(double)value {
    CGRect bounds = self.bounds;
    double unitValue = (value - self.min) / (self.max - self.min);
    return (1.0 - unitValue) * bounds.size.height;
}

- (CGSize)sizeThatFits:(CGSize)size {
    if (size.height == 0)
        size.height = 80;
    size.width = _dataSize;
    return size;
}

- (CGSize)intrinsicContentSize {
    CGSize size;
    size.height = 80;
    size.width = _dataSize;
    return size;
}

@end
