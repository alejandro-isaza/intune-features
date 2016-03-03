//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import Foundation

let cli = CommandLine(arguments: Process.arguments)

// Generation options
let rootFilePath = StringOption(shortFlag: "r", longFlag: "root", required: true, helpMessage: "Path to the audio data.")
let overwrite = BoolOption(longFlag: "overwrite", required: false, helpMessage: "Overwrite existing feature files.")
let windowSize = IntOption(shortFlag: "w", longFlag: "window", required: true, helpMessage: "Audio window size in samples")
let stepSize = IntOption(shortFlag: "s", longFlag: "step", required: true, helpMessage: "Audio window step size in samples")
cli.addOptions(rootFilePath, overwrite, windowSize, stepSize)

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

let featureCompiler = FeatureCompiler(root: rootFilePath.value!, overwrite: overwrite.value, windowSize: windowSize.value!, stepSize: stepSize.value!)

try featureCompiler.compileNoiseFeatures()
try featureCompiler.compileMonoFeatures()
try featureCompiler.compilePolyFeatures()
