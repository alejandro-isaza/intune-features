//  Copyright © 2015 Venture Media. All rights reserved.

import Peak
import FeatureExtraction
import Foundation
import Upsurge

class MonoSequenceBuilder {
    let fileExtensions = [
        "m4a",
        "caf",
        "wav",
        "aiff"
    ]
    
    static let padding = FeatureBuilder.windowSize

    let featureBuilder = FeatureBuilder()

    func forEachSequenceInFolder(folder: String, @noescape action: (Sequence) throws -> ()) rethrows {
        for note in FeatureBuilder.notes {
            let note = Note(midiNoteNumber: note)
            try forEachSequenceInFile(String(note), path: folder, note: note, action: action)
        }
        print("")
    }

    func forEachSequenceInFile(fileName: String, path: String, note: Note, @noescape action: (Sequence) throws -> ()) rethrows {
        let fileManager = NSFileManager.defaultManager()
        for type in fileExtensions {
            let fullFileName = "\(fileName).\(type)"
            let filePath = buildPathFromParts([path, fullFileName])
            if fileManager.fileExistsAtPath(filePath) {
                print("Processing \(filePath)")
                try forEachSequenceInFile(filePath, note: note, action: action)
                break
            }
        }
    }

    func forEachSequenceInFile(filePath: String, note: Note, @noescape action: (Sequence) throws -> ()) rethrows {
        let windowSize = FeatureBuilder.windowSize
        let step = FeatureBuilder.stepSize
        let padding = MonoSequenceBuilder.padding

        let audioFile = AudioFile.open(filePath)!
        guard audioFile.sampleRate == FeatureBuilder.samplingFrequency else {
            fatalError("Sample rate mismatch: \(filePath) => \(audioFile.sampleRate) != \(FeatureBuilder.samplingFrequency)")
        }

        let sequence = Sequence(filePath: filePath, startOffset: -padding)

        let readCount = min(Int(audioFile.frameCount), Sequence.maximumSequenceSamples)
        let sampleCount = max(readCount, FeatureBuilder.windowSize) + padding
        if readCount < FeatureBuilder.windowSize / 2 {
            fatalError("Audio file at '\(filePath)' is too short. Need at least \(FeatureBuilder.windowSize / 2) frames, have \(readCount).")
        }

        sequence.data = RealArray(count: sampleCount)
        for i in 0..<padding { sequence.data[i] = 0 }
        for i in padding+readCount..<sampleCount { sequence.data[i] = 0 }

        guard audioFile.readFrames(sequence.data.mutablePointer + padding, count: readCount) == readCount else {
            return
        }

        let event = Sequence.Event()
        event.offset = padding
        event.notes = [note]
        event.velocities = [0.75]
        sequence.events.append(event)

        let windowCount = FeatureBuilder.windowCountInSamples(sequence.data.count)
        for i in 0..<windowCount-1 {
            let start = i * step
            let end = start + windowSize

            let feature = featureBuilder.generateFeatures(sequence.data[start..<end], sequence.data[start + step..<end + step])
            sequence.features.append(feature)

            let onsetIndexInWindow = padding - start
            if onsetIndexInWindow >= 0 && onsetIndexInWindow < featureBuilder.window.count {
                sequence.featureOnsetValues.append(featureBuilder.window[onsetIndexInWindow])
            } else {
                sequence.featureOnsetValues.append(0)
            }
        }
        precondition(sequence.features.count <= FeatureBuilder.sampleCountInWindows(Sequence.maximumSequenceSamples), "Too many features generated \((sequence.features.count)) for \(filePath)")

        try action(sequence)
    }
}
