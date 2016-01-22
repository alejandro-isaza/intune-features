//  Copyright © 2015 Venture Media. All rights reserved.

import Peak
import FeatureExtraction
import Foundation
import Upsurge

class NoiseExampleBuilder {
    let fileExtensions = [
        "m4a",
        "caf",
        "wav",
        "aiff"
    ]

    let featureBuilder = FeatureBuilder()

    func forEachSequenceInFile(fileName: String, path: String, @noescape action: (Sequence) throws -> ()) rethrows {
        let fileManager = NSFileManager.defaultManager()
        for type in fileExtensions {
            let fullFileName = "\(fileName).\(type)"
            let filePath = buildPathFromParts([path, fullFileName])
            if fileManager.fileExistsAtPath(filePath) {
                print("Processing \(filePath)")
                try forEachSequenceInFile(filePath, action: action)
                break
            }
        }
    }

    func forEachSequenceInFile(filePath: String, @noescape action: (Sequence) throws -> ()) rethrows {
        let windowSize = FeatureBuilder.windowSize
        let step = FeatureBuilder.stepSize

        let audioFile = AudioFile.open(filePath)!
        guard audioFile.sampleRate == FeatureBuilder.samplingFrequency else {
            fatalError("Sample rate mismatch: \(filePath) => \(audioFile.sampleRate) != \(FeatureBuilder.samplingFrequency)")
        }

        let totalSampleCount = Int(audioFile.frameCount)
        let sequenceCount = max(1, totalSampleCount / Sequence.maximumSequenceSamples)
        var offset = 0

        for _ in 0..<sequenceCount {
            let sequence = Sequence(filePath: filePath, startOffset: offset)

            let sampleCount = min(totalSampleCount - offset, Sequence.maximumSequenceSamples)
            if sampleCount < Sequence.minimumSequenceSamples {
                fatalError("Audio file at '\(filePath)' is too short. Need at least \(Sequence.minimumSequenceSamples) frames, have \(sampleCount).")
            }

            sequence.data = RealArray(count: sampleCount)
            guard audioFile.readFrames(sequence.data.mutablePointer, count: sampleCount) == sampleCount else {
                return
            }

            let windowCount = FeatureBuilder.windowCountInSamples(sampleCount)
            for i in 0..<windowCount-1 {
                let start = i * step
                let end = start + windowSize

                let feature = featureBuilder.generateFeatures(sequence.data[start..<end], sequence.data[start + step..<end + step])
                sequence.features.append(feature)
                sequence.featureOnsetValues.append(0)
            }
            
            try action(sequence)
            offset += sampleCount
        }
    }
}
