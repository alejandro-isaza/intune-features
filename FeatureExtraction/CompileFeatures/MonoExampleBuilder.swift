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

    let sampleCount: Int
    let sampleStep: Int
    private var data: (RealArray, RealArray)
    
    init(sampleCount: Int, sampleStep: Int) {
        self.sampleCount = sampleCount
        self.sampleStep = sampleStep
        data.0 = RealArray(count: sampleCount)
        data.1 = RealArray(count: sampleCount)
    }
    
    func forEachExampleInFolder(folder: String, action: Example -> ()) {
        for note in FeatureBuilder.notes {
            forEachExampleInFile(String(note), path: folder, note: note, numExamples: numNoteExamples, action: action)
        }
        print("")
    }

    func forEachExampleInFile(fileName: String, path: String, note: Int, numExamples: Int, action: Example -> ()) {
        let fileManager = NSFileManager.defaultManager()
        let label = FeatureBuilder.labelForNote(note)
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
        var sumsq = 0.0
        var count = 0

        let audioFile = AudioFile.open(filePath)!
        assert(audioFile.sampleRate == 44100)
        guard audioFile.readFrames(data.0.mutablePointer, count: sampleCount) == sampleCount else {
            return
        }
        vDSP_svesqD(data.0.pointer, 1, &sumsq, vDSP_Length(sampleCount))
        count += 1
        audioFile.currentFrame -= sampleCount / 2

        for i in 0..<numExamples {
            guard audioFile.readFrames(data.1.mutablePointer, count: sampleCount) == sampleCount else {
                print("\(i) examples in \(filePath)")
                break
            }

            var x = 0.0
            vDSP_svesqD(data.1.pointer, 1, &x, vDSP_Length(sampleCount))
            sumsq += x
            count += 1

            let example = Example(
                filePath: filePath,
                frameOffset: audioFile.currentFrame,
                label: label,
                data: data)
            action(example)

            audioFile.currentFrame -= sampleCount / 2
            swap(&data.0, &data.1)
        }
    }
}
