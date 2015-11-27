//  Copyright © 2015 Venture Media. All rights reserved.

import Peak
import FeatureExtraction
import Foundation
import Upsurge

class MonoExampleBuilder {
    let fileExtensions = [
        "m4a",
        "caf",
        "wav",
        "aiff"
    ]
    
    let numNoteExamples = 15
    let numNoiseExamples = 1000

    private var data: (RealArray, RealArray)
    
    init() {
        data.0 = RealArray(count: FeatureBuilder.sampleCount)
        data.1 = RealArray(count: FeatureBuilder.sampleCount)
    }
    
    func forEachNoteInFolder(folder: String, action: Example -> ()) {
        for note in FeatureBuilder.notes {
            let label = FeatureBuilder.labelForNote(note)
            forEachExampleInFile(String(note), path: folder, label: label, numExamples: numNoteExamples, action: action)
        }
        print("")
    }

    func forEachNoiseInFolder(folder: String, action: Example -> ()) {
        let label = [Int](count: FeatureBuilder.notes.count, repeatedValue: 0)

        let fileManager = NSFileManager.defaultManager()
        guard let files = try? fileManager.contentsOfDirectoryAtURL(NSURL.fileURLWithPath(folder), includingPropertiesForKeys: [NSURLNameKey], options: NSDirectoryEnumerationOptions.SkipsHiddenFiles) else {
            fatalError("Failed to fetch contents of \(folder)")
        }

        for file in files {
            let filePath = file.path!
            print("Processing \(filePath)")
            forEachExampleInFile(filePath, label: label, numExamples: numNoiseExamples, action: action)
        }
        print("")
    }

    func forEachExampleInFile(fileName: String, path: String, label: [Int], numExamples: Int, action: Example -> ()) {
        let fileManager = NSFileManager.defaultManager()
        for type in fileExtensions {
            let fullFileName = "\(fileName).\(type)"
            let filePath = buildPathFromParts([path, fullFileName])
            if fileManager.fileExistsAtPath(filePath) {
                print("Processing \(filePath)")
                forEachExampleInFile(filePath, label: label, numExamples: numExamples, action: action)
                break
            }
        }
    }

    func forEachExampleInFile(filePath: String, label: [Int], numExamples: Int, action: Example -> ()) {
        let count = FeatureBuilder.sampleCount
        let step = FeatureBuilder.sampleStep
        let overlap = count - step

        for i in 0..<count {
            data.0[i] = 0.0
            data.1[i] = 0.0
        }

        let audioFile = AudioFile.open(filePath)!
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

            let offset = audioFile.currentFrame - count/2
            let time = Double(offset) / FeatureBuilder.samplingFrequency

            let noteStartTime = 0.0
            let shouldLabel = abs(noteStartTime - time) <= FeatureBuilder.maxNoteLag

            let exampleLabel = shouldLabel ? label : [Int](count: label.count, repeatedValue: 0)
            let example = Example(
                filePath: filePath,
                frameOffset: offset,
                label: exampleLabel,
                data: data)
            action(example)
        }
    }
}
