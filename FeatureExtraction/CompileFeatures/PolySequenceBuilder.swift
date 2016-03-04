//  Copyright © 2015 Venture Media. All rights reserved.

import AudioToolbox
import Peak
import FeatureExtraction
import Foundation
import Upsurge

class PolySequenceBuilder {
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

        let newline = NSCharacterSet.newlineCharacterSet()
        var lines: [String] = []
        csvString.stringByTrimmingCharactersInSet(newline).enumerateLines { line, stop in lines.append(line) }
        events.reserveCapacity(lines.count)

        let delimiter = NSCharacterSet(charactersInString: ",")
        for line in lines {
            let values = line.componentsSeparatedByCharactersInSet(delimiter)
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
            if onsetIndexInWindow >= 0 && onsetIndexInWindow < featureBuilder.windowingFunction.count {
                value += Float(featureBuilder.windowingFunction[onsetIndexInWindow])
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
        var value = Float(0)
        for v in values {
            if v > 0 {
                value += 1
            }
        }
        return value
    }

    func notesValueForWindowAt(windowStart: Int) -> [Float] {
        var value = [Float](count: configuration.representableNoteRange.count, repeatedValue: 0)
        for noteNumber in configuration.representableNoteRange {
            let note = Note(midiNoteNumber: noteNumber)
            value[noteNumber - configuration.representableNoteRange.startIndex] = valueForNote(note, windowStart: windowStart)
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
            if event.start > windowStart + configuration.windowSize {
                break
            }
            value += valueForEvent(event, windowStart: windowStart)
        }
        return 2 * value
    }

    func valueForEvent(event: Event, windowStart: Int) -> Float {
        let start = max(event.start, windowStart)
        let end = min(event.start + event.duration, windowStart + configuration.windowSize)

        var value = Float(0)
        for i in start..<end {
            let windowingValue = Float(featureBuilder.windowingFunction[i - windowStart])
            let decayValue = decayModel.decayValueForNote(event.note, atOffset: i - event.start)
            value += decayValue * windowingValue
        }
        value /= decayModel.normalizationForNote(event.note)

        precondition(isfinite(value))
        return value
    }
}
