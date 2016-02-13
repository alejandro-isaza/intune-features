//  Copyright © 2015 Venture Media. All rights reserved.

import AudioToolbox
import Peak
import FeatureExtraction
import Foundation
import Upsurge

class PolySequenceBuilder {
    static let maximumPolyphony = Float(6)

    let featureBuilder = FeatureBuilder()
    var audioFilePath: String
    var midiFilePath: String
    var audioFile: AudioFile
    var events = [Event]()

    init(audioFilePath: String, midiFilePath: String) {
        self.audioFilePath = audioFilePath
        self.midiFilePath = midiFilePath

        audioFile = AudioFile.open(audioFilePath)!
        guard audioFile.sampleRate == FeatureBuilder.samplingFrequency else {
            fatalError("Sample rate mismatch: \(audioFilePath) => \(audioFile.sampleRate) != \(FeatureBuilder.samplingFrequency)")
        }

        guard let midiFile = MIDIFile(filePath: midiFilePath) else {
            fatalError("Failed to open MIDI file \(midiFilePath)")
        }

        let noteEvents = midiFile.noteEvents
        events.reserveCapacity(noteEvents.count)
        for note in noteEvents {
            events.append(Event(midiNoteEvent: note, inFile: midiFile))
        }
    }
    
    func forEachWindow(@noescape action: (Window) throws -> ()) rethrows {
        let windowSize = FeatureBuilder.windowSize
        let stepSize = FeatureBuilder.stepSize

        var data = ValueArray<Double>(capacity: Int(audioFile.frameCount))
        withPointer(&data) { pointer in
            data.count = audioFile.readFrames(pointer, count: data.capacity) ?? 0
        }
        guard data.count >= windowSize + stepSize else {
            return
        }

        let totalSampleCount = Int(audioFile.frameCount)
        for offset in stepSize.stride(through: totalSampleCount - windowSize, by: stepSize) {
            var window = Window(start: offset)

            let range1 = Range(start: offset - stepSize, end: offset - stepSize + windowSize)
            let range2 = Range(start: offset, end: offset + windowSize)
            window.feature = featureBuilder.generateFeatures(data[range1], data[range2])

            window.label.onset = onsetValueForWindowAt(offset)
            window.label.polyphony = polyphonyValueForWindowAt(offset)
            window.label.notes = notesValueFroWindowAt(offset)

            try action(window)
        }
    }

    func onsetValueForWindowAt(windowStart: Int) -> Float {
        var value = Float(0.0)
        var count = 0
        for event in events {
            let onsetIndexInWindow = event.start - windowStart
            if onsetIndexInWindow >= 0 && onsetIndexInWindow < featureBuilder.window.count {
                value += Float(featureBuilder.window[onsetIndexInWindow])
                count += 1
            }
        }
        return value / Float(count)
    }

    func polyphonyValueForWindowAt(windowStart: Int) -> Float {
        var value = Float(0.0)
        for event in events {
            let onsetIndexInWindow = event.start - windowStart
            if onsetIndexInWindow >= 0 && onsetIndexInWindow < featureBuilder.window.count {
                value += Float(featureBuilder.window[onsetIndexInWindow])
            }
        }
        return min(PolySequenceBuilder.maximumPolyphony, value)
    }

    func notesValueFroWindowAt(windowStart: Int) -> [Float] {
        var value = [Float](count: Note.noteCount, repeatedValue: 0)
        for event in events {
            let valueIndex = event.note.midiNoteNumber - Note.representableRange.startIndex
            let onsetIndexInWindow = event.start - windowStart
            if onsetIndexInWindow >= 0 && onsetIndexInWindow < featureBuilder.window.count {
                value[valueIndex] += Float(featureBuilder.window[onsetIndexInWindow])
            }
        }
        return value
    }
}
