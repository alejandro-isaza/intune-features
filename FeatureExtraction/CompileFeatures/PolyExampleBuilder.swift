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
    
    let noteRange = 36...102
    let minOverlapTime = 0.004 // The minum note overlap in seconds to consider a note part of an example
    let sampleCount: Int
    let sampleStep: Int

    var data0: RealArray
    var data1: RealArray
    var rmsContainer = [Real]()
    
    init(sampleCount: Int, sampleStep: Int) {
        self.sampleCount = sampleCount
        self.sampleStep = sampleStep
        data0 = RealArray(count: sampleCount)
        data1 = RealArray(count: sampleCount)
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
        guard let midiFile = MIDIFile(filePath: midiFilePath) else {
            fatalError("Failed to open MIDI file \(midiFilePath)")
        }
        let noteEvents = midiFile.noteEvents

        guard let audioFile = AudioFile.open(audioFilePath) else {
            fatalError("Failed to open audio file \(audioFilePath)")
        }
        assert(audioFile.sampleRate == 44100)

        var offset = 0
        guard audioFile.readFrames(data0.mutablePointer, count: sampleCount) == sampleCount else {
            return
        }
        offset += sampleStep
        audioFile.currentFrame = audioFile.currentFrame - sampleCount + sampleStep

        var onNotes = [Int]()
        while true {
            guard audioFile.readFrames(data1.mutablePointer, count: sampleCount) == sampleCount else {
                break
            }

            let offsetStart = audioFile.currentFrame - sampleCount
            let timeStart = Double(offsetStart) / audioFile.sampleRate
            let beatStart = midiFile.beatsForSeconds(timeStart)

            let offsetEnd = audioFile.currentFrame
            let timeEnd = Double(offsetEnd) / audioFile.sampleRate
            let beatEnd = midiFile.beatsForSeconds(timeEnd)

            onNotes.removeAll(keepCapacity: true)
            let beatRange = beatStart..<beatEnd
            for note in noteEvents {
                let noteStart = note.timeStamp
                if noteStart >= beatEnd {
                    break
                }

                let noteEnd = note.timeStamp + MusicTimeStamp(note.duration)
                if noteEnd < beatStart {
                    continue
                }

                let noteRange = noteStart..<noteEnd
                let overlap = noteRange.clamp(beatRange)
                let overlapTime = midiFile.secondsForBeats(overlap.end) - midiFile.secondsForBeats(overlap.start)
                if overlapTime >= minOverlapTime {
                    onNotes.append(Int(note.note))
                }
            }

            let label = labelForNotes(onNotes)
            let example = Example(
                filePath: audioFilePath,
                frameOffset: (offsetStart + offsetEnd) / 2,
                label: label,
                data: (data0, data1))
            action(example)

            audioFile.currentFrame -= sampleCount
            audioFile.currentFrame += sampleStep
            swap(&data0, &data1)
        }
    }

    func labelForNotes(notes: [Int]) -> [Int] {
        var label = [Int](count: noteRange.count, repeatedValue: 0)
        for note in notes {
            guard noteRange.contains(note) else {
                continue
            }
            let index = note - noteRange.startIndex
            label[index] = 1
        }
        return label
    }

}
