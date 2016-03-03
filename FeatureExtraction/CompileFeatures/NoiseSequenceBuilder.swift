//  Copyright © 2015 Venture Media. All rights reserved.

import Peak
import FeatureExtraction
import Foundation
import Upsurge

class NoiseSequenceBuilder {
    let windowSize: Int
    let stepSize: Int
    let featureBuilder: FeatureBuilder
    var audioFilePath: String
    var audioFile: AudioFile

    init(path: String, windowSize: Int, stepSize: Int) {
        self.windowSize = windowSize
        self.stepSize = stepSize
        featureBuilder = FeatureBuilder(windowSize: windowSize, stepSize: stepSize)
        audioFilePath = path

        audioFile = AudioFile.open(audioFilePath)!
        guard audioFile.sampleRate == Configuration.samplingFrequency else {
            fatalError("Sample rate mismatch: \(audioFilePath) => \(audioFile.sampleRate) != \(Configuration.samplingFrequency)")
        }
    }

    func forEachWindow(@noescape action: (Window) throws -> ()) rethrows {
        let stepSize = featureBuilder.stepSize

        var data = ValueArray<Double>(capacity: Int(audioFile.frameCount))
        withPointer(&data) { pointer in
            data.count = audioFile.readFrames(pointer, count: data.capacity) ?? 0
        }
        guard data.count >= windowSize + stepSize else {
            return
        }

        featureBuilder.reset()
        let totalSampleCount = Int(audioFile.frameCount)
        for offset in stepSize.stride(through: totalSampleCount - windowSize, by: stepSize) {
            var window = Window(start: offset)

            let range1 = Range(start: offset - stepSize, end: offset - stepSize + windowSize)
            let range2 = Range(start: offset, end: offset + windowSize)
            window.feature = featureBuilder.generateFeatures(data[range1], data[range2])

            try action(window)
        }
    }
}
