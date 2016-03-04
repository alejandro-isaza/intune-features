//  Copyright © 2015 Venture Media. All rights reserved.

import Peak
import FeatureExtraction
import Foundation
import Upsurge

class NoiseSequenceBuilder {
    let configuration: Configuration
    let featureBuilder: FeatureBuilder
    var audioFilePath: String
    var audioFile: AudioFile

    init(path: String, configuration: Configuration) {
        self.configuration = configuration
        featureBuilder = FeatureBuilder(configuration: configuration)
        audioFilePath = path

        audioFile = AudioFile.open(audioFilePath)!
        guard audioFile.sampleRate == configuration.samplingFrequency else {
            fatalError("Sample rate mismatch: \(audioFilePath) => \(audioFile.sampleRate) != \(configuration.samplingFrequency)")
        }
    }

    func forEachWindow(@noescape action: (Window) throws -> ()) rethrows {
        var data = ValueArray<Double>(capacity: Int(audioFile.frameCount))
        withPointer(&data) { pointer in
            data.count = audioFile.readFrames(pointer, count: data.capacity) ?? 0
        }
        guard data.count >= configuration.windowSize + configuration.stepSize else {
            return
        }

        featureBuilder.reset()
        let totalSampleCount = Int(audioFile.frameCount)
        for offset in configuration.stepSize.stride(through: totalSampleCount - configuration.windowSize, by: configuration.stepSize) {
            var window = Window(start: offset, noteCount: configuration.representableNoteRange.count, bandCount: configuration.bandCount)

            let range1 = Range(start: offset - configuration.stepSize, end: offset - configuration.stepSize + configuration.windowSize)
            let range2 = Range(start: offset, end: offset + configuration.windowSize)
            window.feature = featureBuilder.generateFeatures(data[range1], data[range2])

            try action(window)
        }
    }
}
