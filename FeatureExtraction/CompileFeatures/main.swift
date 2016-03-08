//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import FeatureExtraction
import Foundation

let cli = CommandLine(arguments: Process.arguments)

// Generation options
let inputFolder = StringOption(shortFlag: "i", longFlag: "input", required: true, helpMessage: "Path to the audio data.")
let outputFolder = StringOption(shortFlag: "o", longFlag: "output", required: true, helpMessage: "Output data folder")
let windowSize = IntOption(shortFlag: "w", longFlag: "window", required: true, helpMessage: "Audio window size in samples")
let stepSize = IntOption(shortFlag: "s", longFlag: "step", required: true, helpMessage: "Audio window step size in samples")
cli.addOptions(inputFolder, outputFolder, windowSize, stepSize)

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

var configuration = Configuration()
configuration.windowSize = windowSize.value!
configuration.stepSize = stepSize.value!
try configuration.serializeToJSON().writeToFile("configuration.json", atomically: true, encoding: NSUTF8StringEncoding)

let featureCompiler = FeatureCompiler(inputFolder: inputFolder.value!, outputFolder: outputFolder.value!, configuration: configuration)

try featureCompiler.compileNoiseFeatures()
try featureCompiler.compileMonoFeatures()
try featureCompiler.compilePolyFeatures()
