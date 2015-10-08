//  Copyright © 2015 Venture Media. All rights reserved.

import AudioKit
import FeatureExtraction
import Foundation
import Surge

class ExampleBuilder {
    let rootPath = "../AudioData/Audio/"
    let trainingFolders = [
        "AcousticGrandPiano_YDP",
        "FFNotes",
        "FluidR3_GM2-2",
        "GeneralUser_GS_MuseScore_v1.442",
        "MFNotes",
        "PPNotes",
        "Piano_Rhodes_73",
        "Piano_Yamaha_DX7",
        "TimGM6mb",
        "VenturePiano",
        "VenturePiano2",
        "VenturePiano3",
        "VenturePiano4"
    ]
    let testingFolders = [
        "Arachno",
    ]
    let testingNoiseFileName = "testingNoise"
    let trainingNoiseFileName = "trainingNoise"
    let fileExtensions = [
        "m4a",
        "caf",
        "wav",
        "aiff"
    ]
    let RMSThreshold = 0.05

    let noteRange: Range<Int>
    let sampleCount: Int
    let labelFunction: Int -> Int
    let noiseLabel = 0
    private var data: [Double]
    
    init(noteRange: Range<Int>, sampleCount: Int, labelFunction: Int -> Int = { $0 }) {
        self.sampleCount = sampleCount
        self.noteRange = noteRange
        self.labelFunction = labelFunction
        data = [Double](count: sampleCount, repeatedValue: 0.0)
    }
    
    func forEachExample(training training: Example -> (), testing: Example -> ()) {
        print("Working Directory: \(NSFileManager.defaultManager().currentDirectoryPath)")
        for folder in trainingFolders {
            forEachExampleInFolder(folder, action: training)
        }
        for folder in testingFolders {
            forEachExampleInFolder(folder, action: testing)
        }

        forEachExampleInFile(trainingNoiseFileName, path: rootPath, label: noiseLabel, action: training)
        forEachExampleInFile(testingNoiseFileName, path: rootPath, label: noiseLabel, action: testing)
    }
    
    func forEachExampleInFolder(folder: String, action: Example -> ()) {
        let path = buildPathFromParts([rootPath, folder])
        for i in noteRange {
            forEachExampleInFile(String(i), path: path, label: labelFunction(i), action: action)
        }
    }

    func forEachExampleInFile(fileName: String, path: String, label: Int, action: Example -> ()) {
        let fileManager = NSFileManager.defaultManager()
        for type in fileExtensions {
            let fullFileName = "\(fileName).\(type)"
            let filePath = buildPathFromParts([path, fullFileName])
            if fileManager.fileExistsAtPath(filePath) {
                forEachExampleInFile(filePath, label: label, action: action)
                break
            }
        }
    }

    func forEachExampleInFile(filePath: String, label: Int, action: Example -> ()) {
        let audioFile = AudioFile(filePath: filePath)!
        assert(audioFile.sampleRate == 44100)

        repeat {
            guard audioFile.readFrames(&data, count: sampleCount) == sampleCount else {
                break
            }

            let example = Example(
                filePath: filePath,
                frameOffset: audioFile.currentFrame,
                label: label,
                data: data)
            action(example)

            audioFile.currentFrame -= sampleCount / 2
        } while rmsq(data) > RMSThreshold
    }
}
