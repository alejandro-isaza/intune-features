//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import Peak

 
let cli = CommandLine(arguments: Process.arguments)

// Input options
let inputOpt = StringOption(shortFlag: "i", longFlag: "input", required: true, helpMessage: "Input MIDI file to process.")
cli.addOptions(inputOpt)

// Output options
let midiOutputOpt = StringOption(shortFlag: "m", longFlag: "midi-output", required: true, helpMessage: "Output path to write processed MIDI file.")
cli.addOptions(midiOutputOpt)

let refOutputOpt = StringOption(shortFlag: "r", longFlag: "ref-output", required: true, helpMessage: "Output path to write chord reference file.")
cli.addOptions(refOutputOpt)



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

guard let inputFilePath = inputOpt.value else {
    fatalError("No input file supplied via '--input -i'.")
}

guard let midiOutputFilePath = midiOutputOpt.value else {
    fatalError("No midi output file supplied.")
}

guard let refOutputFilePath = refOutputOpt.value else {
    fatalError("No chord reference output file supplied.")
}


guard let inputFile = MIDIFile(filePath: inputFilePath) else {
    fatalError("Could not open: \(inputFilePath)")
}

let midiMixer = MIDIMixer(inputFile: inputFile)
 midiMixer.mix()
var outputSequence = midiMixer.constructSequence()

guard let outputFile = MIDIFile.create(midiOutputFilePath, sequence: outputSequence) else {
    fatalError("Could not open: \(midiOutputFilePath)")
}

let url = NSURL.fileURLWithPath(refOutputFilePath)
let referenceText = midiMixer.referenceIndices.reduce("", combine: { "\($0.0)\($0.1)\n" })
do {
    try referenceText.writeToURL(url, atomically: true, encoding: NSUTF8StringEncoding)
} catch {
    fatalError("Could not write chord reference file")
}
