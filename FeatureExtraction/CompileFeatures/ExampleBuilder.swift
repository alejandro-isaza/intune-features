//  Copyright © 2015 Venture Media. All rights reserved.

import Peak
import FeatureExtraction
import Foundation
import Upsurge

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
        "VentureQuietPiano2",
        "VentureQuietPiano3",
        "VentureQuietPiano4"
    ]
    let testingFolders = [
        "Arachno",
        "VentureQuietPiano1",
    ]
    let testingNoiseFileName = "testingnoise"
    let trainingNoiseFileName = "trainingnoise"
    let fileExtensions = [
        "m4a",
        "caf",
        "wav",
        "aiff"
    ]
    let RMSThreshold = 0.01

    let noteRange: Range<Int>
    let sampleCount: Int
    let labelFunction: Int -> Int
    let noiseLabel = 0
    private var data: ([Double], [Double])
    
    init(noteRange: Range<Int>, sampleCount: Int, labelFunction: Int -> Int = { $0 }) {
        self.sampleCount = sampleCount
        self.noteRange = noteRange
        self.labelFunction = labelFunction
        data.0 = [Double](count: sampleCount, repeatedValue: 0.0)
        data.1 = [Double](count: sampleCount, repeatedValue: 0.0)
    }
    
    func forEachExample(training training: Example -> (), testing: Example -> ()) {
        print("Working Directory: \(NSFileManager.defaultManager().currentDirectoryPath)")
        for folder in trainingFolders {
            forEachExampleInFolder(folder, action: training, minRMS: RMSThreshold)
        }
        for folder in testingFolders {
            forEachExampleInFolder(folder, action: testing, minRMS: RMSThreshold)
        }

        forEachExampleInFile(trainingNoiseFileName, path: rootPath, label: noiseLabel, action: training, minRMS: 0.0)
        forEachExampleInFile(testingNoiseFileName, path: rootPath, label: noiseLabel, action: testing, minRMS: 0.0)
    }
    
    func forEachExampleInFolder(folder: String, action: Example -> (), minRMS: Double) {
        let path = buildPathFromParts([rootPath, folder])
        for i in noteRange {
            forEachExampleInFile(String(i), path: path, label: labelFunction(i), action: action, minRMS: minRMS)
        }
    }

    func forEachExampleInFile(fileName: String, path: String, label: Int, action: Example -> (), minRMS: Double) {
        let fileManager = NSFileManager.defaultManager()
        for type in fileExtensions {
            let fullFileName = "\(fileName).\(type)"
            let filePath = buildPathFromParts([path, fullFileName])
            if fileManager.fileExistsAtPath(filePath) {
                print("Processing \(filePath)")
                forEachExampleInFile(filePath, label: label, action: action, minRMS: minRMS)
                break
            }
        }
    }

    func forEachExampleInFile(filePath: String, label: Int, action: Example -> (), minRMS: Double) {
        let audioFile = AudioFile(filePath: filePath)!
        assert(audioFile.sampleRate == 44100)
        guard audioFile.readFrames(&data.0, count: sampleCount) == sampleCount else {
            return
        }

        while rmsq(data.0) > minRMS {
            guard audioFile.readFrames(&data.1, count: sampleCount) == sampleCount else {
                break
            }

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
