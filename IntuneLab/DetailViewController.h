//
//  DetailViewController.h
//  IntuneLab
//
//  Created by Alejandro Isaza on 2014-11-14.
//  Copyright (c) 2014 Venture Media Labs. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;
@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end

