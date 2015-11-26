//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import Foundation

let cli = CommandLine(arguments: Process.arguments)

// Generation options
let trainingFilePath = StringOption(longFlag: "training", required: false, helpMessage: "Path to the training HDF5 file. Default: training.h5")
let testingFilePath = StringOption(longFlag: "testing", required: false, helpMessage: "Path to the testing HDF5 file. Default: testing.h5")
let noGenerate = BoolOption(longFlag: "no-generate", required: false, helpMessage: "Don't generate training and testing data.")
let overwite = BoolOption(shortFlag: "o", longFlag: "overwrite", required: false, helpMessage: "Overwrite existing data. By default new data is appended.")
cli.addOptions(trainingFilePath, testingFilePath, noGenerate, overwite)

// Shuffling options
let noShuffle = BoolOption(longFlag: "no-shuffle", required: false, helpMessage: "Don't shuffle data.")
let shuffleChunkSize = IntOption(longFlag: "chunk", helpMessage: "The size of chunks to shuffle. Default: 10240")
let shufflePasses = IntOption(longFlag: "passes", helpMessage: "The number of shuffling passes to perform. Default: 1")
cli.addOptions(noShuffle, shuffleChunkSize, shufflePasses)

// Other options
let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints a help message.")
cli.addOptions(help)

do {
    try cli.parse()
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}

if help.value {
    cli.printUsage()
    exit(EX_OK)
}

let featureCompiler = FeatureCompiler(overwrite: overwite.value)
if let path = trainingFilePath.value {
    featureCompiler.trainingFileName = path
}
if let path = testingFilePath.value {
    featureCompiler.testingFileName = path
}

if !noGenerate.value {
    featureCompiler.compileNoiseFeatures()
    featureCompiler.compileMonoFeatures()
    featureCompiler.compilePolyFeatures()
}

if !noShuffle.value {
    featureCompiler.shuffle(chunkSize: shuffleChunkSize.value ?? 10240, passes: shufflePasses.value ?? 1)
}
