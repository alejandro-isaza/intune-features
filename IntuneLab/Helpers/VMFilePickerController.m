//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMFilePickerController.h"

@interface VMFilePickerController () <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong) NSMutableArray* filesArray;
@property(nonatomic, strong) UITableView* tableView;

@end

@implementation VMFilePickerController

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return self;

    _filesArray = [NSMutableArray array];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;

    [self.view addSubview:_tableView];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tableView]|" options:0 metrics:nil views:@{@"tableView": _tableView}]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tableView]|" options:0 metrics:nil views:@{@"tableView": _tableView}]];

    [self loadDataSource];

    return self;
}

- (void)loadDataSource {
    NSString* bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Audio"];
    NSArray* bundleFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundlePath error:nil];
    for (NSString *file in bundleFiles)
        [_filesArray addObject:@{@"file": [bundlePath stringByAppendingPathComponent:file], @"filename": file}];

    NSString* documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSArray* documentsFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsPath error:nil];
    for (NSString *file in documentsFiles)
        [_filesArray addObject:@{@"file": [documentsPath stringByAppendingPathComponent:file], @"filename": file}];

    [_tableView reloadData];
}

- (void)presentInViewController:(UIViewController*)sourceViewController sourceRect:(CGRect)sourceRect {
    self.modalPresentationStyle = UIModalPresentationPopover;
    [sourceViewController presentViewController:self animated:YES completion:nil];

    UIPopoverPresentationController *presentationController = [self popoverPresentationController];
    presentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    presentationController.sourceView = sourceViewController.view;
    presentationController.sourceRect = sourceRect;
}

+ (NSString*)annotationsForFilePath:(NSString*)path {
    NSString* audioBundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Audio"];
    if ([path hasPrefix:audioBundlePath]) {
        NSString* annotationsBundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Annotations"];
        NSString* fileName = [[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"json"];
        return [annotationsBundlePath stringByAppendingPathComponent:fileName];
    }

    NSString* documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    if ([path hasPrefix:documentsPath]) {
        NSString* fileName = [[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"json"];
        return [documentsPath stringByAppendingPathComponent:fileName];
    }

    return nil;
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _filesArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"fileCell"];

    NSDictionary *fileDictionary = [_filesArray objectAtIndex:indexPath.row];
    cell.textLabel.text = fileDictionary[@"filename"];

    return cell;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *fileDictionary = [_filesArray objectAtIndex:indexPath.row];
    if (_selectionBlock)
        _selectionBlock(fileDictionary[@"file"], fileDictionary[@"filename"]);

    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
