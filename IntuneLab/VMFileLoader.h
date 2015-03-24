//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import <Foundation/Foundation.h>

#include <tempo/Buffer.h>

using VMFileLoaderDataType = double;
typedef void (^VMFileLoaderLoadedBlock)(const tempo::Buffer<VMFileLoaderDataType>&);
typedef void (^VMFileLoaderInvalidatedBlock)();


/**
 Loads audio and spectrogram data from a file.
 */
@interface VMFileLoader : NSObject

+ (instancetype)fileLoaderWithPath:(NSString*)path;

@property(nonatomic, strong, readonly) NSString* filePath;

@property(nonatomic) double sampleRate;
@property(nonatomic) NSTimeInterval windowTime;
@property(nonatomic) std::size_t windowSize;
@property(nonatomic) NSTimeInterval hopTime;
@property(nonatomic) std::size_t hopSize;
@property(nonatomic) BOOL normalize;

- (const tempo::Buffer<VMFileLoaderDataType>*)audioData;
- (const tempo::Buffer<VMFileLoaderDataType>*)spectrogramData;
- (const tempo::Buffer<VMFileLoaderDataType>*)peakData;

- (void)loadAudioData:(VMFileLoaderLoadedBlock)completion;
- (void)loadSpectrogramData:(VMFileLoaderLoadedBlock)completion;
- (void)loadPeakData:(VMFileLoaderLoadedBlock)completion;

@end
