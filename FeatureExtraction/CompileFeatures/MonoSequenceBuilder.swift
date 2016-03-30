//  Copyright © 2015 Venture Media. All rights reserved.

import Peak
import FeatureExtraction
import Foundation
import Upsurge

class MonoSequenceBuilder {
    let decayModel: DecayModel
    let configuration: Configuration
    let padding: Int
    let featureBuilder: FeatureBuilder
    
    var audioFilePath: String
    var audioFile: AudioFile
    var event: Event

    init(path: String, note: Note, decayModel: DecayModel, configuration: Configuration) {
        self.decayModel = decayModel
        self.configuration = configuration
        padding = configuration.windowSize
        featureBuilder = FeatureBuilder(configuration: configuration)
        
        audioFilePath = path
        audioFile = AudioFile.open(path)!
        event = Event(note: note, start: padding, duration: Int(audioFile.frameCount), velocity: 0.63)

        guard audioFile.sampleRate == configuration.samplingFrequency else {
            fatalError("Sample rate mismatch: \(audioFilePath) => \(audioFile.sampleRate) != \(configuration.samplingFrequency)")
        }
    }

    func forEachWindow(@noescape action: (Window) throws -> ()) rethrows {
        var data = ValueArray<Double>(capacity: Int(audioFile.frameCount) + padding)

        // Pad at the start
        for _ in 0..<padding {
            data.append(0)
        }

        // Read audio
        withPointer(&data) { pointer in
            data.count += audioFile.readFrames(pointer + padding, count: data.capacity - padding) ?? 0
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

            let onsetIndexInWindow = padding - offset
            if onsetIndexInWindow >= 0 && onsetIndexInWindow < featureBuilder.windowingFunction.count {
                let windowingScale = Float(featureBuilder.windowingFunction[onsetIndexInWindow])
                window.label.onset = windowingScale
            }

            let value = noteValue(offset)
            window.label.notes[event.note.midiNoteNumber - configuration.representableNoteRange.startIndex] = value
            window.label.polyphony = value == 0 ? 0 : 1

            try action(window)
        }
    }

    func noteValue(windowStart: Int) -> Float {
        let start = max(event.start, windowStart)
        let end = min(event.start + event.duration, windowStart + configuration.windowSize)

        var value = Float(0)
        for i in start..<end {
            let windowingValue = Float(featureBuilder.windowingFunction[i - windowStart])
            let decayValue = decayModel.decayValueForNote(event.note, atOffset: i - event.start)
            value += decayValue * windowingValue
        }
        value /= decayModel.normalizationForNote(event.note, windowSize: configuration.windowSize)

        precondition(isfinite(value))
        return 2 * value
    }
}

func *=(inout array: [Float], scale: Float) {
    for i in 0..<array.count {
        array[i] *= scale
    }
}
