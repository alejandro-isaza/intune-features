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

    private var data: (RealArray, RealArray)
    
    init() {
        data.0 = RealArray(count: FeatureBuilder.sampleCount)
        data.1 = RealArray(count: FeatureBuilder.sampleCount)
    }
    
    func forEachExampleInFolder(path: String, action: Example -> ()) {
        let fileManager = NSFileManager.defaultManager()
        
        guard let files = try? fileManager.contentsOfDirectoryAtURL(NSURL.fileURLWithPath(path), includingPropertiesForKeys: [NSURLNameKey], options: NSDirectoryEnumerationOptions.SkipsHiddenFiles) else {
            fatalError("Failed to fetch contents of \(path)")
        }
        let midiFiles = files.filter{ $0.path!.containsString(".mid") }
        
        for file in midiFiles {
            forEachExampleInFile(file.path!.stringByReplacingOccurrencesOfString(".mid", withString: ""), action: action)
        }
        print("")
    }
    
    func forEachExampleInFile(filePath: String, action: Example -> ()) {
        let fileManager = NSFileManager.defaultManager()
        
        let midiFilePath = "\(filePath).\(midiFileExtension)"

        for ext in audioFileExtensions {
            let audioFilePath = "\(filePath).\(ext)"
            
            if fileManager.fileExistsAtPath(audioFilePath) {
                print("Processing \(audioFilePath)")
                forEachExampleInAudioFile(audioFilePath, midiFilePath: midiFilePath, action: action)
                break
            }
        }
    }
    
    func forEachExampleInAudioFile(audioFilePath: String, midiFilePath: String, action: Example -> ()) {
        let count = FeatureBuilder.sampleCount
        let step = FeatureBuilder.sampleStep
        let overlap = count - step

        guard let midiFile = MIDIFile(filePath: midiFilePath) else {
            fatalError("Failed to open MIDI file \(midiFilePath)")
        }
        let noteEvents = midiFile.noteEvents

        for i in 0..<count {
            data.0[i] = 0.0
            data.1[i] = 0.0
        }

        let audioFile = AudioFile.open(audioFilePath)!
        assert(audioFile.sampleRate == FeatureBuilder.samplingFrequency)
        guard audioFile.readFrames(data.1.mutablePointer + overlap, count: step) == step else {
            return
        }

        while true {
            data.0.mutablePointer.assignFrom(data.0.mutablePointer + step, count: overlap)
            (data.0.mutablePointer + overlap).assignFrom(data.1.mutablePointer + overlap, count: step)

            data.1.mutablePointer.assignFrom(data.1.mutablePointer + step, count: overlap)
            guard audioFile.readFrames(data.1.mutablePointer + overlap, count: step) == step else {
                break
            }

            // Offset of the middle of the current window
            let offset = audioFile.currentFrame - count/2

            // Time in seconds for the middle of the current window
            let time = Double(offset) / FeatureBuilder.samplingFrequency

            // Discard margin in seconds
            let margin = (1.0 / 8.0) * Double(count) / FeatureBuilder.samplingFrequency

            let offsetStart = audioFile.currentFrame - count
            let timeStart = margin + Double(offsetStart) / FeatureBuilder.samplingFrequency
            let beatStart = midiFile.beatsForSeconds(timeStart)

            let offsetEnd = audioFile.currentFrame
            let timeEnd = Double(offsetEnd) / FeatureBuilder.samplingFrequency - margin
            let beatEnd = midiFile.beatsForSeconds(timeEnd)

            var label = Label()
            for note in noteEvents {
                let noteStart = note.timeStamp
                let noteEnd = noteStart + MusicTimeStamp(note.duration)

                // Ignore note events before the current window
                if noteEnd < beatStart {
                    continue
                }

                // Stop at the first note past the current window
                if noteStart > beatEnd {
                    break
                }

                let noteStartTime = midiFile.secondsForBeats(noteStart)
                label.addNote(Note(midiNoteNumber: Int(note.note)), atTime: noteStartTime - time)
            }

            let example = Example(
                filePath: audioFilePath,
                frameOffset: offset,
                label: label,
                data: data)
            action(example)
        }
    }

    func labelForNotes(notes: [Int]) -> [Int] {
        var label = [Int](count: FeatureBuilder.notes.count, repeatedValue: 0)
        for note in notes {
            guard FeatureBuilder.notes.contains(note) else {
                continue
            }
            let index = note - FeatureBuilder.notes.startIndex
            label[index] = 1
        }
        return label
    }

}
