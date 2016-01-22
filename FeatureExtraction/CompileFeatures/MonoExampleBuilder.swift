//  Copyright © 2015 Venture Media. All rights reserved.

import Peak
import FeatureExtraction
import Foundation
import Upsurge

class MonoExampleBuilder {
    let fileExtensions = [
        "m4a",
        "caf",
        "wav",
        "aiff"
    ]
    
    static let padding = FeatureBuilder.windowSize

    let featureBuilder = FeatureBuilder()

    func forEachNoteSequenceInFolder(folder: String, @noescape action: (Sequence) throws -> ()) rethrows {
        for note in FeatureBuilder.notes {
            let note = Note(midiNoteNumber: note)
            try forEachSequenceInFile(String(note), path: folder, note: note, action: action)
        }
        print("")
    }

    func forEachNoiseSequenceInFolder(folder: String, @noescape action: (Sequence) throws -> ()) rethrows {
        let fileManager = NSFileManager.defaultManager()
        guard let files = try? fileManager.contentsOfDirectoryAtURL(NSURL.fileURLWithPath(folder), includingPropertiesForKeys: [NSURLNameKey], options: NSDirectoryEnumerationOptions.SkipsHiddenFiles) else {
            fatalError("Failed to fetch contents of \(folder)")
        }

        for file in files {
            let filePath = file.path!
            print("Processing \(filePath)")
            try forEachSequenceInFile(filePath, note: nil, action: action)
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

    func forEachSequenceInFile(filePath: String, note: Note?, @noescape action: (Sequence) throws -> ()) rethrows {
        let windowSize = FeatureBuilder.windowSize
        let step = FeatureBuilder.stepSize
        let padding = MonoExampleBuilder.padding

        let audioFile = AudioFile.open(filePath)!
        guard audioFile.sampleRate == FeatureBuilder.samplingFrequency else {
            fatalError("Sample rate mismatch: \(filePath) => \(audioFile.sampleRate) != \(FeatureBuilder.samplingFrequency)")
        }

        let sequence = Sequence(filePath: filePath, startOffset: -padding)

        let frameCount = min(Int(audioFile.frameCount) + padding, Sequence.maximumSequenceSamples)
        if frameCount < Sequence.minimumSequenceSamples {
            fatalError("Audio file at '\(filePath)' is too short. Need at least \(Sequence.minimumSequenceSamples) frames, have \(frameCount).")
        }

        sequence.data = RealArray(count: frameCount)
        for i in 0..<padding { sequence.data[i] = 0 }

        let readCount = frameCount - padding
        guard audioFile.readFrames(sequence.data.mutablePointer + padding, count: readCount) == readCount else {
            return
        }

        let event = Sequence.Event()
        event.offset = padding
        if let note = note {
            event.notes = [note]
            event.velocities = [0.75]
        }
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

        try action(sequence)
    }
}
