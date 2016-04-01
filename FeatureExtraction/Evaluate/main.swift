//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import FeatureExtraction
import NeuralNet
import Upsurge

let cli = CommandLine(arguments: Process.arguments)

// Input options
let audioFileOpt = StringOption(shortFlag: "a", longFlag: "audio", required: true, helpMessage: "Audio file.")
let midiFileOpt = StringOption(shortFlag: "m", longFlag: "midi", required: false, helpMessage: "MIDI file.")
let networkOpt = StringOption(shortFlag: "n", longFlag: "network", required: true, helpMessage: "Network weights and biases.")
let configOpt = StringOption(shortFlag: "c", longFlag: "config", required: true, helpMessage: "Configuration options JSON file.")
cli.addOptions(audioFileOpt, midiFileOpt, networkOpt, configOpt)

// Output options
let outputFileOpt = StringOption(shortFlag: "o", longFlag: "output", required: false, helpMessage: "Output CSV file.")
cli.addOptions(outputFileOpt)

// Other options
let helpOpt = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints a help message.")
cli.addOptions(helpOpt)

do {
    try cli.parse()
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}

if helpOpt.value {
    cli.printUsage()
    exit(EX_OK)
}

guard let configuration = Configuration(file: configOpt.value!) else {
    exit(EX_DATAERR)
}

let networkEval = NetworkEval(configuration: configuration)
networkEval.run()
