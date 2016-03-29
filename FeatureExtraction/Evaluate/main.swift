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

var results = [(polyphony: Float, onset: Float, notes: ValueArray<Float>)]()
let neuralNet = try! NeuralNet(file: networkOpt.value!, configuration: configuration)
neuralNet.forwardPassAction = { snapshot in
    if !isfinite(snapshot.polyphony) || !isfinite(snapshot.onset) || !snapshot.notes.map({ isfinite($0) }).reduce(true, combine: { $0 && $1 }) {
        print("Network output NaN")
    }
    results.append((polyphony: snapshot.polyphony, onset: snapshot.onset, notes: snapshot.notes))
}

var windows = [Window]()
let decayModel = DecayModel(representableNoteRange: configuration.representableNoteRange)
let audioFile = audioFileOpt.value!
let midiFile = midiFileOpt.value ?? audioFile.stringByReplacingExtensionWith("mid")
let featureBuilder = PolySequenceBuilder(audioFilePath: audioFile, midiFilePath: midiFile, decayModel: decayModel, configuration: configuration)
featureBuilder.forEachWindow { window in
    windows.append(window)
    if !isfinite(window.label.onset) || !isfinite(window.label.polyphony) || !window.label.notes.map({ isfinite($0) }).reduce(true, combine: { $0 && $1 }) {
        print("Found NaN in labels")
    }
    if !window.feature.spectrum.map({ isfinite($0) }).reduce(true, combine: { $0 && $1 }) {
        print("Found NaN in spectrum")
    }
    if !window.feature.spectralFlux.map({ isfinite($0) }).reduce(true, combine: { $0 && $1 }) {
        print("Found NaN in spectralFlux")
    }
    if !window.feature.peakHeights.map({ isfinite($0) }).reduce(true, combine: { $0 && $1 }) {
        print("Found NaN in peakHeights")
    }
    if !window.feature.peakLocations.map({ isfinite($0) }).reduce(true, combine: { $0 && $1 }) {
        print("Found NaN in peakLocations")
    }
    if !window.feature.peakFlux.map({ isfinite($0) }).reduce(true, combine: { $0 && $1 }) {
        print("Found NaN in peakFlux")
    }
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
