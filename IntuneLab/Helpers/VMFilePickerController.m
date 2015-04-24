//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMFilePickerController.h"

static NSString* const kRootPath = @"Audio";

@interface VMFilePickerController () <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong) NSMutableArray* filesArray;
@property(nonatomic, strong) UITableView* tableView;
@property(nonatomic, strong) NSString* filesPath;

@end

@implementation VMFilePickerController

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return self;

    _filesArray = [NSMutableArray array];
    _filesPath = kRootPath;

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
    [_filesArray removeAllObjects];

    NSString* bundlePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:_filesPath];
    NSArray* bundleFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundlePath error:nil];
    for (NSString *file in bundleFiles)
        [_filesArray addObject:@{@"file": [bundlePath stringByAppendingPathComponent:file], @"filename": file}];

    if (![self isShowingBack]) {
        NSString* documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSArray* documentsFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsPath error:nil];
        for (NSString *file in documentsFiles)
            [_filesArray addObject:@{@"file": [documentsPath stringByAppendingPathComponent:file], @"filename": file}];
    }

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
        path = [path stringByReplacingOccurrencesOfString:@"Audio" withString:@"Annotations"];
        path = [path stringByReplacingOccurrencesOfString:@".caf" withString:@".json"];
        return path;
    }

    NSString* documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    if ([path hasPrefix:documentsPath]) {
        NSString* fileName = [[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"json"];
        return [documentsPath stringByAppendingPathComponent:fileName];
    }

    return nil;
}

- (BOOL)isFolder:(NSString*)path {
    return [[path pathExtension] isEqual:@""];
}

- (NSInteger)indexForRow:(NSInteger)row {
    return [_filesPath isEqual:kRootPath] ? row : row - 1;
}

- (BOOL)isShowingBack {
    return [_filesPath isEqual:kRootPath] == NO;
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger additionalRows = [self isShowingBack] ? 1 : 0;
    return _filesArray.count + additionalRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"fileCell"];

    if (indexPath.row == 0 && [self isShowingBack]) {
        cell.textLabel.text = @"Back";
    } else {
        NSDictionary *fileDictionary = [_filesArray objectAtIndex:[self indexForRow:indexPath.row]];
        cell.textLabel.text = fileDictionary[@"filename"];
    }

    return cell;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Back tapped
    if (indexPath.row == 0 && [self isShowingBack]) {
        _filesPath = [_filesPath stringByDeletingLastPathComponent];
        [self loadDataSource];
        return;
    }

    // Folder tapped
    NSDictionary *fileDictionary = [_filesArray objectAtIndex:[self indexForRow:indexPath.row]];
    if ([self isFolder:fileDictionary[@"file"]]) {
        _filesPath = [_filesPath stringByAppendingPathComponent:fileDictionary[@"filename"]];
        [self loadDataSource];
        return;
    }

    // File tapped
    if (_selectionBlock)
        _selectionBlock(fileDictionary[@"file"], fileDictionary[@"filename"]);
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
