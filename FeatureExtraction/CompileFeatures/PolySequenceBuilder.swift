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
    let decayModel = DecayModel()

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
            window.label.notes = notesValueForWindowAt(offset)
            window.label.polyphony = polyphonyValueFromNoteValues(window.label.notes)

            precondition(isfinite(window.label.onset))

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
        if count > 0 {
            value /= Float(count)
        }

        precondition(isfinite(value))
        return value
    }

    func polyphonyValueFromNoteValues(values: [Float]) -> Float {
        return sum(values)
    }

    func notesValueForWindowAt(windowStart: Int) -> [Float] {
        var value = [Float](count: Note.noteCount, repeatedValue: 0)
        for noteNumber in Note.representableRange {
            let note = Note(midiNoteNumber: noteNumber)
            value[noteNumber - Note.representableRange.startIndex] = valueForNote(note, windowStart: windowStart)
        }
        return value
    }

    func valueForNote(note: Note, windowStart: Int) -> Float {
        var value = Float(0)
        for event in events {
            if event.note != note {
                continue
            }
            if event.start + event.duration < windowStart {
                continue
            }
            if event.start > windowStart + FeatureBuilder.windowSize {
                break
            }
            value += valueForEvent(event, windowStart: windowStart)
        }
        return value
    }

    func valueForEvent(event: Event, windowStart: Int) -> Float {
        let start = max(event.start, windowStart)
        let end = min(event.start + event.duration, windowStart + FeatureBuilder.windowSize)

        var value = Float(0)
        for i in start..<end {
            let windowingValue = Float(featureBuilder.window[i - windowStart])
            let decayValue = decayModel.decayValueForNote(event.note, atOffset: i - event.start)
            value += decayValue * windowingValue
        }
        value /= decayModel.normalizationForNote(event.note)

        precondition(isfinite(value))
        return value
    }
}
