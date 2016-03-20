//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import FeatureExtraction
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

var results = [(polyphony: Float, onset: Float, notes: ValueArray<Float>)]()
let neuralNet = try! NeuralNet(file: networkOpt.value!, configuration: configuration)
neuralNet.forwardPassAction = { polyphony, onset, notes in
    results.append((polyphony: polyphony, onset: onset, notes: notes))
}

var windows = [Window]()
let decayModel = DecayModel(representableNoteRange: configuration.representableNoteRange)
let audioFile = audioFileOpt.value!
let midiFile = midiFileOpt.value ?? audioFile.stringByReplacingExtensionWith("mid")
let featureBuilder = PolySequenceBuilder(audioFilePath: audioFile, midiFilePath: midiFile, decayModel: decayModel, configuration: configuration)
featureBuilder.forEachWindow { window in
    windows.append(window)
    neuralNet.processFeature(window.feature)
}

// Wait for neural net to finish processing
while results.count < windows.count {
    NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 1))
}
assert(windows.count == results.count)

// Compare
let noteCount = configuration.representableNoteRange.count
var polyphonyDistance = 0.0
var onsetDistance = 0.0
var notesDistance = ValueArray<Double>(count: noteCount, repeatedValue: 0)
for (window, result) in zip(windows, results) {
    let pd = Double(window.label.polyphony - result.polyphony)
    polyphonyDistance += pd * pd / Double(windows.count)

    let od = Double(window.label.onset - result.onset)
    onsetDistance += od * od / Double(windows.count)

    for i in 0..<noteCount {
        let nd = Double(window.label.notes[i] - result.notes[i])
        notesDistance[i] += nd * nd / Double(windows.count)
    }
}

if let output = outputFileOpt.value {
    var string = "\(audioFileOpt.value!), "
    string += "\(mean(notesDistance)), \(polyphonyDistance), \(onsetDistance), "
    for d in notesDistance {
        string += "\(d), "
    }
    string += "\n"

    if let handle = NSFileHandle(forWritingAtPath: output) {
        handle.seekToEndOfFile()
        handle.writeData(string.dataUsingEncoding(NSUTF8StringEncoding)!)
        handle.closeFile()
    } else {
        try! string.writeToFile(output, atomically: true, encoding: NSUTF8StringEncoding)
    }
} else {
    print("Polyphony distance: \(polyphonyDistance)")
    print("Onset distance: \(onsetDistance)")
    print("Notes distance:")
    for d in notesDistance {
        print("\(d)")
    }
    print("Max note error: \(max(notesDistance))")
    print("Mean note error: \(mean(notesDistance))")
}
