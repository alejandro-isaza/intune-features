//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import Foundation

let cli = CommandLine(arguments: Process.arguments)

// Generation options
let rootFilePath = StringOption(shortFlag: "r", longFlag: "root", required: true, helpMessage: "Path to the audio data.")
cli.addOptions(rootFilePath)

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

let featureCompiler = FeatureCompiler(root: rootFilePath.value!)

try featureCompiler.compileNoiseFeatures()
try featureCompiler.compileMonoFeatures()
try featureCompiler.compilePolyFeatures()
