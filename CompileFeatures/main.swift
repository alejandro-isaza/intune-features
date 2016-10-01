// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import IntuneFeatures
import Foundation

func printUsage() {
    print("")
    print("CompileFeatures generates an HDF5 database file for each annotated audio file.")
    print("The database includes features for every window in the audio file as well as")
    print("labels based on an optional MIDI file with the same base name as the audio")
    print("file.")
    print("")
    print("Usage: CompileFeatures OPTIONS")
    print("")
    print("Options:")
    print("-i, --input    The directory where input audio and MIDI files reside.")
    print("-o, --output   The directory to place the output .h5 files")
    print("-w, --window   The window size to use when generating features. Needs to be a")
    print("               power of two, e.g. 8192")
    print("-s, --step     The step size between consecutive windows.")
    print("-h, --help     Show this help and exit.")
}

if let helpIndex = CommandLine.arguments.index(where: { $0.hasPrefix("-h") || $0.hasPrefix("--help") }) {
    printUsage()
    exit(EXIT_SUCCESS)
}

let inputPath: String
if let inputIndex = CommandLine.arguments.index(where: { $0.hasPrefix("-i") || $0.hasPrefix("--input") }) , inputIndex < CommandLine.arguments.count - 1 {
    inputPath = CommandLine.arguments[inputIndex + 1]
} else {
    printUsage()
    exit(EX_USAGE)
}

let outputPath: String
if let outputIndex = CommandLine.arguments.index(of: "-o") ?? CommandLine.arguments.index(of: "--output") , outputIndex < CommandLine.arguments.count - 1 {
    outputPath = CommandLine.arguments[outputIndex + 1]
} else {
    printUsage()
    exit(EX_USAGE)
}

let windowSize: Int
if let windowIndex = CommandLine.arguments.index(of: "-w") ?? CommandLine.arguments.index(of: "--window") , windowIndex < CommandLine.arguments.count - 1 {
    windowSize = Int(CommandLine.arguments[windowIndex + 1])!
} else {
    printUsage()
    exit(EX_USAGE)
}

let stepSize: Int
if let stepIndex = CommandLine.arguments.index(of: "-s") ?? CommandLine.arguments.index(of: "--step") , stepIndex < CommandLine.arguments.count - 1 {
    stepSize = Int(CommandLine.arguments[stepIndex + 1])!
} else {
    printUsage()
    exit(EX_USAGE)
}

var configuration = Configuration()
configuration.windowSize = windowSize
configuration.stepSize = stepSize
try configuration.serializeToJSON().write(toFile: "configuration.json", atomically: true, encoding: String.Encoding.utf8)

let featureCompiler = FeatureCompiler(inputFolder: inputPath, outputFolder: outputPath, configuration: configuration)

try featureCompiler.compileFeatures()
