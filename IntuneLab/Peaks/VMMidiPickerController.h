//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>


@interface VMMidiPickerController : UIViewController

@property (nonatomic, copy) void (^selectionBlock)(NSSet*);
@property(nonatomic, strong) NSMutableSet* selectedKeys;

- (void)presentInViewController:(UIViewController*)sourceViewController sourceRect:(CGRect)sourceRect;

@end
