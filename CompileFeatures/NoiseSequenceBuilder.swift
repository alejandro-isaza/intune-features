// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Peak
import IntuneFeatures
import Foundation
import Upsurge

class NoiseSequenceBuilder: Builder {
    let configuration: Configuration
    let featureBuilder: FeatureBuilder
    var audioFilePath: String
    var audioFile: AudioFile

    /// Noise files never have events
    let events = [Event]()

    init(audioFilePath path: String, configuration: Configuration) {
        self.configuration = configuration
        featureBuilder = FeatureBuilder(configuration: configuration)
        audioFilePath = path

        audioFile = AudioFile.open(audioFilePath)!
        guard audioFile.sampleRate == configuration.samplingFrequency else {
            fatalError("Sample rate mismatch: \(audioFilePath) => \(audioFile.sampleRate) != \(configuration.samplingFrequency)")
        }
    }

    func forEachWindow(_ action: (Window) throws -> ()) rethrows {
        var data = ValueArray<Double>(capacity: Int(audioFile.frameCount))
        withPointer(&data) { pointer in
            data.count = audioFile.readFrames(pointer, count: data.capacity) ?? 0
        }
        guard data.count >= configuration.windowSize + configuration.stepSize else {
            return
        }

        featureBuilder.reset()
        let totalSampleCount = Int(audioFile.frameCount)
        for offset in stride(from: configuration.stepSize, through: totalSampleCount - configuration.windowSize, by: configuration.stepSize) {
            var window = Window(start: offset, noteCount: configuration.representableNoteRange.count, bandCount: configuration.bandCount)

            let range1 = offset - configuration.stepSize..<offset - configuration.stepSize + configuration.windowSize
            let range2 = offset..<offset + configuration.windowSize
            featureBuilder.generateFeatures(data[range1], data[range2], feature: &window.feature)

            try action(window)
        }
    }
}
