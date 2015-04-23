//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMMidiPickerController.h"

static const NSInteger kBaseOctaveValue = 1;
static const NSInteger kBaseMidiValue = 12 + 12 * kBaseOctaveValue;

@interface VMMidiPickerController () <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong) NSMutableArray* keysArray;
@property(nonatomic, strong) UITableView* tableView;

@end

@implementation VMMidiPickerController

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return self;

    _keysArray = [NSMutableArray array];
    _selectedKeys = [NSMutableSet set];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.allowsMultipleSelection = YES;
    _tableView.rowHeight = 44;
    _tableView.contentOffset = CGPointMake(0, 12 * 4 * _tableView.rowHeight); // Move to octave 4

    [self.view addSubview:_tableView];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tableView]|" options:0 metrics:nil views:@{@"tableView": _tableView}]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tableView]|" options:0 metrics:nil views:@{@"tableView": _tableView}]];

    [self loadDataSource];

    return self;
}

- (void)loadDataSource {
    NSArray* baseKeysArray = @[@"C", @"C#", @"D", @"D#", @"E", @"F", @"F#", @"G", @"G#", @"A", @"A#", @"B"];
    _keysArray = [NSMutableArray array];
    for (int octave = 0; octave < 7; octave += 1) {
        for (int key = 0; key < baseKeysArray.count; key += 1) {
            NSString* baseKey = [baseKeysArray objectAtIndex:key];
            NSMutableString* midiKey = [baseKey mutableCopy];
            [midiKey insertString:@(octave + kBaseOctaveValue).description atIndex:1];
            [midiKey insertString:[NSString stringWithFormat:@"%d - ", [self midiValueForRow:octave * baseKeysArray.count + key]] atIndex:0];
            [_keysArray addObject:midiKey];
        }
    }

    [_tableView reloadData];
}

- (NSInteger)midiValueForRow:(NSInteger)row {
    return row + kBaseMidiValue;
}

- (void)presentInViewController:(UIViewController*)sourceViewController sourceRect:(CGRect)sourceRect {
    self.modalPresentationStyle = UIModalPresentationPopover;
    [sourceViewController presentViewController:self animated:YES completion:nil];

    UIPopoverPresentationController *presentationController = [self popoverPresentationController];
    presentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    presentationController.sourceView = sourceViewController.view;
    presentationController.sourceRect = sourceRect;
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _keysArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"keyCell"];
    cell.textLabel.text = [_keysArray objectAtIndex:indexPath.row];
    cell.detailTextLabel.text = [_selectedKeys containsObject:@([self midiValueForRow:indexPath.row])] ? @"\u2713" : @"";
    return cell;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([_selectedKeys containsObject:@([self midiValueForRow:indexPath.row])])
        [_selectedKeys removeObject:@([self midiValueForRow:indexPath.row])];
    else
        [_selectedKeys addObject:@([self midiValueForRow:indexPath.row])];

    if (_selectionBlock)
        _selectionBlock(_selectedKeys);

    [tableView reloadData];
}

@end
