//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

#import "MasterViewController.h"
#import "RecordViewController.h"

@interface MasterViewController ()

@end

@implementation MasterViewController

- (void)awakeFromNib {
    [super awakeFromNib];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        UIViewController *detailController =  [[segue destinationViewController] topViewController];
        detailController.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        detailController.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

@end
