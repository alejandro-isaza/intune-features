//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>


@interface VMFilePickerController : UIViewController

@property (nonatomic, copy) void (^selectionBlock)(NSString*, NSString*);

- (void)presentInViewController:(UIViewController*)sourceViewController sourceRect:(CGRect)sourceRect;

@end
