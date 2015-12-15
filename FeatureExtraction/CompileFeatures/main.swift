//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import Foundation

let cli = CommandLine(arguments: Process.arguments)

// Generation options
let rootFilePath = StringOption(shortFlag: "r", longFlag: "root", required: true, helpMessage: "Path to the audio data.")
let outputFilePath = StringOption(shortFlag: "o", longFlag: "output", required: true, helpMessage: "Path to the HDF5 file.")
let noGenerate = BoolOption(longFlag: "no-generate", required: false, helpMessage: "Don't generate training and testing data.")
let overwite = BoolOption(longFlag: "overwrite", required: false, helpMessage: "Overwrite existing data. By default new data is appended.")
cli.addOptions(rootFilePath, outputFilePath, noGenerate, overwite)

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

let featureCompiler = FeatureCompiler(root: rootFilePath.value!, output: outputFilePath.value!, overwrite: overwite.value)

if !noGenerate.value {
    try featureCompiler.compileNoiseFeatures()
    try featureCompiler.compileMonoFeatures()
    try featureCompiler.compilePolyFeatures()
}

if !noShuffle.value {
    try featureCompiler.shuffle(chunkSize: shuffleChunkSize.value ?? 10240, passes: shufflePasses.value ?? 1)
}
