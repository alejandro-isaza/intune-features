//  Copyright © 2015 Venture Media. All rights reserved.

import AudioToolbox
import Peak
import FeatureExtraction
import Foundation
import Upsurge

class PolySequenceBuilder {
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

        let splitter = Splitter(midiFile: midiFile)
        let noteSequences = splitter.split()
        for noteSequence in noteSequences {
            let startTime = midiFile.secondsForBeats(noteSequence.first!.timeStamp)
            let startSample = Int(startTime * FeatureBuilder.samplingFrequency) - windowSize

            var endTime = midiFile.secondsForBeats(noteSequence.last!.timeStamp + Double(noteSequence.last!.duration))
            if endTime - startTime > Sequence.maximumSequenceDuration || endTime - startTime < Sequence.minimumSequenceDuration {
                precondition(midiFile.secondsForBeats(noteSequence.last!.timeStamp) - startTime < Sequence.maximumSequenceDuration, "Note sequence contains too many notes in \(audioFilePath)")
                endTime = startTime + Sequence.maximumSequenceDuration
            }
            let endSample = Int(endTime * FeatureBuilder.samplingFrequency)

            let windowCount = FeatureBuilder.windowCountInSamples(endSample - startSample)
            let sampleCount = FeatureBuilder.sampleCountInWindows(windowCount)

            let offset = max(startSample, 0)
            let sequence = Sequence(filePath: audioFilePath, startOffset: offset)

            audioFile.currentFrame = offset
            sequence.data = ValueArray<Double>(count: sampleCount)
            let readCount = withPointer(&sequence.data) { pointer in
                return audioFile.readFrames(pointer, count: sampleCount)
            }
            guard readCount == sampleCount else {
                return
            }

            sequence.events = sequenceEventsFromNoteEvents(noteSequence, baseOffset: offset, midiFile: midiFile, cutoffOffset: endSample)

            for i in 0..<windowCount-1 {
                let start = i * stepSize
                let end = start + windowSize
                let feature = featureBuilder.generateFeatures(sequence.data[start..<end], sequence.data[start + stepSize..<end + stepSize])
                sequence.features.append(feature)
                sequence.featureOnsetValues.append(onsetValueForWindowAt(start + stepSize, events: sequence.events))
                sequence.featurePolyphonyValues.append(polyphonyValueForWindowAt(start + stepSize, events: sequence.events))
            }
            precondition(sequence.features.count <= FeatureBuilder.sampleCountInWindows(Sequence.maximumSequenceSamples), "Too many features generated \((sequence.features.count)) for \(audioFilePath)")

            try action(sequence)
        }
    }

    func sequenceEventsFromNoteEvents(noteEvents: [MIDINoteEvent], baseOffset offset: Int, midiFile: MIDIFile, cutoffOffset: Int) -> [Sequence.Event] {
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
            if sample > cutoffOffset {
                break
            }

            event.offset = sample - offset
            event.notes = notes.map({ $0.0 })
            event.velocities = notes.map({ Float($0.1) })
            events.append(event)
        }

        return events
    }

    func onsetValueForWindowAt(windowStart: Int, events: [Sequence.Event]) -> Float {
        var value = Float(0.0)
        for event in events {
            let index = event.offset - windowStart
            if index >= 0 && index < featureBuilder.window.count {
                value += Float(featureBuilder.window[index])
            }
        }
        return value
    }

    func polyphonyValueForWindowAt(windowStart: Int, events: [Sequence.Event]) -> Float {
        var value = Float(0.0)
        for event in events {
            let index = event.offset - windowStart
            if index >= 0 && index < featureBuilder.window.count {
                value += 1
            }
        }
        return value
    }
}
