//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "VMSpectrogramViewController.h"
#import "IntuneLab-Swift.h"

#import "VMFilePickerController.h"

#include <tempo/modules/Converter.h>
#include <tempo/modules/FFTModule.h>
#include <tempo/modules/HammingWindow.h>
#include <tempo/modules/PollingModule.h>
#include <tempo/modules/WindowingModule.h>


using namespace tempo;
using DataType = double;
using SizeType = SourceModule<DataType>::SizeType;

static const double kSampleRate = 44100;
static const SizeType kMaxDataSize = 128*1024*1024;


@interface VMSpectrogramViewController () <UIScrollViewDelegate>

@property(nonatomic, weak) IBOutlet VMSpectrogramView *spectrogramView;
@property(nonatomic, weak) IBOutlet VMEqualizerView *equalizerView;

@property(nonatomic, strong) NSString* filePath;
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, assign) CGPoint previousOffset;
@end


@implementation VMSpectrogramViewController {
    std::unique_ptr<DataType[]> _data;
}

+ (instancetype)create {
    return [[VMSpectrogramViewController alloc] initWithNibName:@"VMSpectrogramViewController" bundle:nil];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self)
        return nil;

    _queue = dispatch_queue_create("VMSpectrogramViewController", DISPATCH_QUEUE_SERIAL);
    _windowTime = 0.05;
    _hopTime = _windowTime / 2;

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _spectrogramView.delegate = self;
}

- (void)setWindowTime:(NSTimeInterval)windowTime hopTime:(NSTimeInterval)hopTime {
    _windowTime = windowTime;
    _hopTime = hopTime;
    dispatch_async(_queue, ^() {
        [self render];
    });
}

- (void)setDecibelGround:(double)decibelGround {
    _spectrogramView.decibelGround = decibelGround;
    dispatch_async(_queue, ^() {
        [self render];
    });
}

- (void)getData:(DataType**)data count:(NSInteger*)count {
    *data = _data.get();
}

- (void)setSpectrogramHighColor:(UIColor *)spectrogramColor {
    _spectrogramView.highColor = spectrogramColor;
}

- (void)setSpectrogramLowColor:(UIColor *)spectrogramColor {
    _spectrogramView.lowColor = spectrogramColor;
}

- (IBAction)open:(UIButton *)sender {
    VMFilePickerController *filePicker = [[VMFilePickerController alloc] init];
    filePicker.selectionBlock = ^(NSString* file, NSString* filename) {
        [self loadWaveform:file];
    };
    [filePicker presentInViewController:self sourceRect:sender.frame];
}

- (void)loadWaveform:(NSString*)file {
    self.filePath = file;
    dispatch_async(_queue, ^() {
        [self render];
    });
}

- (void)render {
    if (!self.filePath)
        return;

    auto fileModule = std::make_shared<ReadFromFileModule>(self.filePath.UTF8String);
    const auto fileLength = fileModule->lengthInFrames();

    auto converter = std::make_shared<Converter<ReadFromFileModule::DataType, DataType>>();
    converter->setSource(fileModule);

    const auto windowSize = static_cast<SizeType>(_windowTime * kSampleRate);
    auto hopSize = static_cast<SizeType>(_hopTime * kSampleRate);
    if (fileLength / hopSize >= kMaxDataSize / windowSize) {
        hopSize = static_cast<decltype(hopSize)>(static_cast<uint64_t>(fileLength) * static_cast<uint64_t>(windowSize) / kMaxDataSize);
        _hopTime = static_cast<NSTimeInterval>(hopSize) / kSampleRate;
        // TODO: Update settings view controller
    }

    auto windowingModule = std::make_shared<WindowingModule<DataType>>(windowSize, hopSize);
    windowingModule->setSource(converter);

    auto windowModule = std::make_shared<HammingWindow<DataType>>();
    windowModule->setSource(windowingModule);

    auto fftModule = std::make_shared<FFTModule<DataType>>(windowSize);
    fftModule->setSource(windowModule);

    auto pollingModule = std::make_shared<PollingModule<DataType>>();
    pollingModule->setSource(fftModule);

    const auto dataLength = (fileLength / hopSize) * windowSize;

    dispatch_sync(dispatch_get_main_queue(), ^() {
        // Fill buffer on main thread or we may write over a buffer being drawn
        _data.reset(new DataType[dataLength]);
        PointerBuffer<DataType> buffer(_data.get(), dataLength);
        auto rendered = pollingModule->render(buffer);
        
        self.spectrogramView.sampleTimeLength = _hopTime;
        self.spectrogramView.frequencyCount = windowSize / 2;
        [self.spectrogramView setSamples:_data.get() count:rendered];
    });
}

- (void)scrollBy:(CGFloat)dx {
    CGPoint currentOffset = _spectrogramView.contentOffset;
    currentOffset.x += dx;
    _spectrogramView.contentOffset = currentOffset;
}


#pragma mark - Gestures

- (IBAction)handleTap:(UITapGestureRecognizer *)sender {
    CGPoint tapLocation = [sender locationInView:_spectrogramView];
    NSInteger sampleOffset = [_spectrogramView sampleOffsetAtLocation:tapLocation];

    DataType* start = _data.get() + (sampleOffset * _spectrogramView.frequencyCount);
    [_equalizerView setSamples:start count:_spectrogramView.frequencyCount];
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGPoint currentOffset = scrollView.contentOffset;
    CGFloat dx = currentOffset.x - _previousOffset.x;
    _previousOffset = currentOffset;

    if (_didScrollBlock)
        _didScrollBlock(dx); // hmm maybe send back sample offset?
}

@end
