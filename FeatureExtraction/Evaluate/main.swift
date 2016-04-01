//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import FeatureExtraction
import NeuralNet
import Upsurge

let cli = CommandLine(arguments: Process.arguments)

// Input options
let audioFileOpt = StringOption(shortFlag: "a", longFlag: "audio", required: true, helpMessage: "Audio file.")
let midiFileOpt = StringOption(shortFlag: "m", longFlag: "midi", required: false, helpMessage: "MIDI file.")
let refMidiFileOpt = StringOption(shortFlag: "r", longFlag: "ref", required: false, helpMessage: "Reference MIDI file.")
let cursorMappingOpt = StringOption(shortFlag: "u", longFlag: "cursor", required: true, helpMessage: "Mapping from reference cursor positions to playback cursor positions.")
let networkOpt = StringOption(shortFlag: "n", longFlag: "network", required: true, helpMessage: "Network weights and biases.")
let configOpt = StringOption(shortFlag: "c", longFlag: "config", required: true, helpMessage: "Configuration options JSON file.")
cli.addOptions(audioFileOpt, midiFileOpt, refMidiFileOpt, cursorMappingOpt, networkOpt, configOpt)

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
    print("Failed to load configuration file")
    exit(EX_DATAERR)
}

let audioFile = audioFileOpt.value!
let midiFile = midiFileOpt.value ?? audioFile.stringByReplacingExtensionWith("mid")

if let refMidiFile = refMidiFileOpt.value, playMidiFile = midiFileOpt.value, cursorMappingFile = cursorMappingOpt.value {
    let cursorMappingsData = NSData(contentsOfFile: cursorMappingFile)!
    let cursorMappingsString = String(data: cursorMappingsData, encoding: NSUTF8StringEncoding)!
    let cursorMappings = cursorMappingsString.characters.split("\n").map({ Int(String($0))! })

    let trackerEval = TrackerEval(configuration: configuration, referenceMIDIPath: refMidiFileOpt.value!, playbackMIDIPath: midiFileOpt.value!, playbackAudioPath: audioFileOpt.value!, cursorMappings: cursorMappings)
    trackerEval.run()
} else {
    let networkEval = NetworkEval(configuration: configuration, networkFile: networkOpt.value!, audioFile: audioFile, midiFile: midiFile, outputFile: outputFileOpt.value)
    networkEval.run()
}
