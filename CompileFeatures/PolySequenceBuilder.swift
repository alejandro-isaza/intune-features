// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import AudioToolbox
import Peak
import IntuneFeatures
import Foundation
import Upsurge

class PolySequenceBuilder: Builder {
    let decayModel: DecayModel
    let configuration: Configuration
    let featureBuilder: FeatureBuilder
    
    var audioFilePath: String
    var audioFile: AudioFile
    var events = [Event]()

    init(audioFilePath: String, midiFilePath: String, decayModel: DecayModel, configuration: Configuration) {
        self.decayModel = decayModel
        self.configuration = configuration
        featureBuilder = FeatureBuilder(configuration: configuration)

        self.audioFilePath = audioFilePath

        audioFile = AudioFile.open(audioFilePath)!
        guard audioFile.sampleRate == configuration.samplingFrequency else {
            fatalError("Sample rate mismatch: \(audioFilePath) => \(audioFile.sampleRate) != \(configuration.samplingFrequency)")
        }

        guard let midiFile = MIDIFile(filePath: midiFilePath) else {
            fatalError("Failed to open MIDI file \(midiFilePath)")
        }

        let noteEvents = midiFile.noteEvents
        events.reserveCapacity(noteEvents.count)
        for note in noteEvents {
            events.append(Event(midiNoteEvent: note, inFile: midiFile, samplingFrequency: configuration.samplingFrequency))
        }
    }

    init(audioFilePath: String, csvFilePath: String, decayModel: DecayModel, configuration: Configuration) {
        self.decayModel = decayModel
        self.configuration = configuration
        featureBuilder = FeatureBuilder(configuration: configuration)

        self.audioFilePath = audioFilePath
        
        audioFile = AudioFile.open(audioFilePath)!
        guard audioFile.sampleRate == configuration.samplingFrequency else {
            fatalError("Sample rate mismatch: \(audioFilePath) => \(audioFile.sampleRate) != \(configuration.samplingFrequency)")
        }

        guard let csvString = try? String(contentsOfFile: csvFilePath) else {
            fatalError("Failed to open CSV file \(csvFilePath)")
        }

        let newline = NSCharacterSet.newlines
        var lines: [String] = []
        csvString.trimmingCharacters(in: newline).enumerateLines { line, stop in lines.append(line) }
        events.reserveCapacity(lines.count)

        let delimiter = CharacterSet(charactersIn: ",")
        for line in lines {
            let values = line.components(separatedBy: delimiter)
            precondition(values.count == 4 || values.count == 3, "Invalid CSV file")
            let note = Note(midiNoteNumber: Int(values[0])!)
            let start = Int(values[1])!
            let duration = Int(values[2])!

            var velocity = 63
            if values.count >= 4 {
                velocity = Int(values[3])!
            }

            let event = Event(note: note, start: start, duration: duration, velocity: Float(velocity) / 127.0)
            events.append(event)
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

            window.label.onset = onsetValueForWindowAt(offset)
            window.label.notes = notesValueForWindowAt(offset)
            window.label.polyphony = polyphonyValueFromNoteValues(window.label.notes)

            precondition(window.label.onset.isFinite)

            try action(window)
        }
    }

    func onsetValueForWindowAt(_ windowStart: Int) -> Float {
        var value = Float(0.0)
        var count = 0
        for event in events {
            let onsetIndexInWindow = event.start - windowStart
            if onsetIndexInWindow >= 0 && onsetIndexInWindow < featureBuilder.windowingFunction.count {
                value += Float(featureBuilder.windowingFunction[onsetIndexInWindow])
                count += 1
            }
        }
        if count > 0 {
            value /= Float(count)
        }

        precondition(value.isFinite)
        return value
    }

    func polyphonyValueFromNoteValues(_ values: [Float]) -> Float {
        var value = Float(0)
        for v in values {
            if v > 0 {
                value += 1
            }
        }
        return value
    }

    func notesValueForWindowAt(_ windowStart: Int) -> [Float] {
        var value = [Float](repeating: 0, count: configuration.representableNoteRange.count)
        for noteNumber in configuration.representableNoteRange {
            let note = Note(midiNoteNumber: noteNumber)
            value[noteNumber - configuration.representableNoteRange.start!] = valueForNote(note, windowStart: windowStart)
        }
        return value
    }

    func valueForNote(_ note: Note, windowStart: Int) -> Float {
        var value = Float(0)
        for event in events {
            if event.note != note {
                continue
            }
            if event.start + event.duration < windowStart {
                continue
            }
            if event.start > windowStart + configuration.windowSize {
                break
            }
            value += valueForEvent(event, windowStart: windowStart)
        }
        return 2 * value
    }

    func valueForEvent(_ event: Event, windowStart: Int) -> Float {
        let start = max(event.start, windowStart)
        let end = min(event.start + event.duration, windowStart + configuration.windowSize)

        var value = Float(0)
        for i in start..<end {
            let windowingValue = Float(featureBuilder.windowingFunction[i - windowStart])
            let decayValue = decayModel.decayValueForNote(event.note, atOffset: i - event.start)
            value += decayValue * windowingValue
        }
        value /= decayModel.normalizationForNote(event.note, windowSize: configuration.windowSize)

        precondition(value.isFinite)
        return value
    }
}
