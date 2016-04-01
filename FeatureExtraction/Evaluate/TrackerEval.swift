//  Copyright © 2016 Venture Media. All rights reserved.

import FeatureExtraction
import NeuralNet
import Peak
import Tracker
import Upsurge

class TrackerEval {
    let configuration: Configuration
    let tracker: Tracker

    let referenceMIDIPath: String
    let referenceMIDI: MIDIFile
    let referenceOnsets: [Onset]

    let playbackMIDIPath: String
    let playbackMIDI: MIDIFile
    let playbackOnsets: [Onset]

    let playbackAudio: String
    let cursorMappings = [(Int, Int)]()

    var count = 0
    var time = 0.0
    var cursorLocations = [Double: Int]()

    init(configuration: Configuration, referenceMIDIPath: String, playbackMIDIPath: String, playbackAudioPath: String, cursorMappings: [(Int, Int)]) {
        self.configuration = configuration

        self.referenceMIDIPath = referenceMIDIPath
        referenceMIDI = MIDIFile(filePath: referenceMIDIPath)!
        referenceOnsets = onsetsFromMIDI(referenceMIDI)

        self.playbackMIDIPath = playbackMIDIPath
        playbackMIDI = MIDIFile(filePath: playbackMIDIPath)!
        playbackOnsets = onsetsFromMIDI(playbackMIDI)

        self.playbackAudio = playbackAudioPath

        let midi = MIDIFile(filePath: referenceMIDIPath)!
        tracker = Tracker(onsets: onsetsFromMIDI(midi), configuration: configuration)
        tracker.didMoveCursorAction = { index in
            self.cursorLocations[self.time] = index
        }
    }

    func run() {
        let neuralNet = try! NeuralNet(networkFile: networkOpt.value!, configuration: configuration)
        neuralNet.forwardPassAction = { snapshot in
            if !isfinite(snapshot.polyphony) || !isfinite(snapshot.onset) || !snapshot.notes.map({ isfinite($0) }).reduce(true, combine: { $0 && $1 }) {
                print("Network output NaN")
            }
            self.tracker.update(snapshot.onset, notes: snapshot.notes)
            self.time += Double(self.configuration.stepSize) / self.configuration.samplingFrequency
            self.count += 1
        }

        var windowCount = 0
        let decayModel = DecayModel(representableNoteRange: configuration.representableNoteRange)
        let featureBuilder = PolySequenceBuilder(audioFilePath: playbackAudio, midiFilePath: playbackMIDIPath, decayModel: decayModel, configuration: configuration)
        featureBuilder.forEachWindow { window in
            windowCount += 1
            neuralNet.processFeature(window.feature)
        }

        // Wait for neural net to finish processing
        while count < windowCount {
            NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 1))
        }
        assert(windowCount == count)

        var matches = 0
        var total = 0
        for (t, i) in cursorLocations {
            let playbeat = playbackMIDI.beatsForSeconds(t)
            let playOnsetIndex = onsetIndexAtBeat(playbeat, onsets: playbackOnsets)

            if cursorMappings.contains({ $0 == (i, playOnsetIndex) }) {
                matches += 1
            }
            total += 1
        }
    }

    func onsetIndexAtBeat(beat: Double, onsets: [Onset]) -> Int {
        var index: Int?
        for (i, onset) in onsets.enumerate() {
            if onset.start < beat {
                index = i
            } else if let index = index {
                return index
            }
        }
        return 0
    }
}
