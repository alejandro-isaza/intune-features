//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import Peak

 
let cli = CommandLine(arguments: Process.arguments)

// Input options
let inputOpt = StringOption(shortFlag: "i", longFlag: "input", required: true, helpMessage: "Input MIDI file to process.")
cli.addOptions(inputOpt)

// Output options
let outputOpt = StringOption(shortFlag: "o", longFlag: "output", required: true, helpMessage: "Output path to write processed MIDI file.")
cli.addOptions(outputOpt)

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

guard let outputFilePath = outputOpt.value else {
    fatalError("No output file supplied via '--output -o'.")
}

guard let inputFile = MIDIFile(filePath: inputFilePath) else {
    fatalError("Could not open: \(inputFilePath)")
}

let midiMixer = MIDIMixer(inputFile: inputFile)
var outputSequence = midiMixer.mix()

guard let outputFile = MIDIFile.create(outputFilePath, sequence: outputSequence) else {
    fatalError("Could not open: \(outputFilePath)")
}
