//  Copyright © 2015 Venture Media. All rights reserved.

import AudioToolbox
import Peak
import FeatureExtraction
import Foundation
import Upsurge

class PolyExampleBuilder {
    let audioFileExtensions = [
        "mp3",
        "wav",
        "m4a"
    ]
    let midiFileExtension = "mid"

    let featureBuilder = FeatureBuilder()
    
    func forEachSequenceInFolder(path: String, @noescape action: (Sequence) throws -> ()) rethrows {
        let fileManager = NSFileManager.defaultManager()
        
        guard let files = try? fileManager.contentsOfDirectoryAtURL(NSURL.fileURLWithPath(path), includingPropertiesForKeys: [NSURLNameKey], options: NSDirectoryEnumerationOptions.SkipsHiddenFiles) else {
            fatalError("Failed to fetch contents of \(path)")
        }
        let midiFiles = files.filter{ $0.path!.containsString(".mid") }
        
        for file in midiFiles {
            try forEachSequenceInFile(file.path!.stringByReplacingOccurrencesOfString(".mid", withString: ""), action: action)
        }
        print("")
    }
    
    func forEachSequenceInFile(filePath: String, @noescape action: (Sequence) throws -> ()) rethrows {
        let fileManager = NSFileManager.defaultManager()
        
        let midiFilePath = "\(filePath).\(midiFileExtension)"

        for ext in audioFileExtensions {
            let audioFilePath = "\(filePath).\(ext)"
            
            if fileManager.fileExistsAtPath(audioFilePath) {
                print("Processing \(audioFilePath)")
                try forEachSequenceInAudioFile(audioFilePath, midiFilePath: midiFilePath, action: action)
                break
            }
        }
    }
    
    func forEachSequenceInAudioFile(audioFilePath: String, midiFilePath: String, @noescape action: (Sequence) throws -> ()) rethrows {
        let windowSize = FeatureBuilder.windowSize
        let stepSize = FeatureBuilder.stepSize

        guard let midiFile = MIDIFile(filePath: midiFilePath) else {
            fatalError("Failed to open MIDI file \(midiFilePath)")
        }

        guard let audioFile = AudioFile.open(audioFilePath) else {
            fatalError("Failed to open audio file \(audioFilePath)")
        }
        assert(audioFile.sampleRate == FeatureBuilder.samplingFrequency)

        let noteSequences = splitEvents(midiFile)
        for noteSequence in noteSequences {
            let startTime = midiFile.secondsForBeats(noteSequence.first!.timeStamp)
            let startSample = Int(startTime * FeatureBuilder.samplingFrequency) - windowSize

            let endTime = midiFile.secondsForBeats(noteSequence.last!.timeStamp + Double(noteSequence.last!.duration))
            let endSample = Int(endTime * FeatureBuilder.samplingFrequency)

            let windowCount = FeatureBuilder.windowCountInSamples(endSample - startSample)
            let sampleCount = FeatureBuilder.sampleCountInWindows(windowCount)

            let offset = max(startSample, 0)
            let sequence = Sequence(filePath: audioFilePath, startOffset: offset)

            audioFile.currentFrame = offset
            sequence.data = RealArray(count: sampleCount)
            guard audioFile.readFrames(sequence.data.mutablePointer, count: sampleCount) == sampleCount else {
                return
            }

            sequence.events = sequenceEventsFromNoteEvents(noteSequence, baseOffset: offset, midiFile: midiFile)

            for i in 0..<windowCount-1 {
                let start = i * stepSize
                let end = start + windowSize
                let feature = featureBuilder.generateFeatures(sequence.data[start..<end], sequence.data[start + stepSize..<end + stepSize])
                sequence.features.append(feature)
                sequence.featureOnsetValues.append(onsetValueForWindowAt(start + stepSize, events: sequence.events))
            }

            try action(sequence)
        }
    }

    func splitEvents(midiFile: MIDIFile) -> [[MIDINoteEvent]] {
        let events = midiFile.noteEvents

        var sequences = [[MIDINoteEvent]]()
        var currentSequence = [MIDINoteEvent]()
        var currentSequenceStartBeat = 0.0
        var currentSequenceEndBeat = 0.0
        var currentSequenceStartTime = 0.0
        var currentSequenceEndTime = 0.0

        for event in events {
            let eventStart = event.timeStamp
            let eventEnd = eventStart + Double(event.duration)

            if eventStart >= currentSequenceStartBeat && eventStart < currentSequenceEndBeat {
                // Event fits in the current sequence
                currentSequence.append(event)
                currentSequenceEndBeat = max(currentSequenceEndBeat, eventEnd)
                currentSequenceEndTime = midiFile.secondsForBeats(currentSequenceEndBeat)
                continue
            }

            if currentSequenceEndTime - currentSequenceStartTime < Sequence.minimumSequenceDuration {
                // Increase sequence length
                currentSequence.append(event)
                currentSequenceEndBeat = eventEnd
                currentSequenceEndTime = midiFile.secondsForBeats(currentSequenceEndBeat)
                continue
            }

            // End current sequence
            sequences.append(currentSequence)
            currentSequence.removeAll()

            // Start a new sequence
            currentSequenceStartBeat = eventStart
            currentSequenceStartTime = midiFile.secondsForBeats(eventStart)
            currentSequenceEndBeat = eventEnd
            currentSequenceEndTime = midiFile.secondsForBeats(eventEnd)
        }

        return sequences
    }

    func sequenceEventsFromNoteEvents(noteEvents: [MIDINoteEvent], baseOffset offset: Int, midiFile: MIDIFile) -> [Sequence.Event] {
        var notesByBeat = [Double: [(Note, Double)]]()
        for noteEvent in noteEvents {
            let note = Note(midiNoteNumber: Int(noteEvent.note))
            let velocity = min(1, Double(noteEvent.velocity) / 127.0)

            if let notes = notesByBeat[noteEvent.timeStamp] {
                var newNotes = notes
                newNotes.append((note, velocity))
                notesByBeat.updateValue(newNotes, forKey: noteEvent.timeStamp)
            } else {
                notesByBeat[noteEvent.timeStamp] = [(note, velocity)]
            }
        }

        var events: [Sequence.Event] = []
        for (beat, notes) in notesByBeat {
            let event = Sequence.Event()
            let time = midiFile.secondsForBeats(beat)
            let sample = Int(time * FeatureBuilder.samplingFrequency)
            event.offset = sample - offset
            event.notes = notes.map({ $0.0 })
            event.velocities = notes.map({ $0.1 })
            events.append(event)
        }

        return events
    }

    func onsetValueForWindowAt(windowStart: Int, events: [Sequence.Event]) -> Double {
        var value = 0.0
        for event in events {
            let index = event.offset - windowStart
            if index >= 0 && index < featureBuilder.window.count {
                value += featureBuilder.window[index]
            }
        }
        return value
    }
}
