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
        "VenturePianoQuiet2",
        "VenturePianoQuiet3",
        "VenturePianoQuiet4"
    ]
    let testingFolders = [
        "Arachno",
        "VenturePianoQuiet1",
    ]
    let testingNoiseFileName = "testingnoise"
    let trainingNoiseFileName = "trainingnoise"
    let fileExtensions = [
        "m4a",
        "caf",
        "wav",
        "aiff"
    ]
    
    let numNoteExamples = 10
    let numNoiseExamples = 200

    let noteRange: Range<Int>
    let sampleCount: Int
    let labelFunction: Int -> Int
    let noiseLabel = 0
    private var data: ([Double], [Double])

    private var rmsContainer = [Double]()
    
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
            forEachExampleInFolder(folder, action: training)
        }
        for folder in testingFolders {
            forEachExampleInFolder(folder, action: testing)
        }

        forEachExampleInFile(trainingNoiseFileName, path: rootPath, label: noiseLabel, numExamples: numNoiseExamples, action: training)
        forEachExampleInFile(testingNoiseFileName, path: rootPath, label: noiseLabel, numExamples: numNoiseExamples, action: testing)
    }
    
    func forEachExampleInFolder(folder: String, action: Example -> ()) {
        rmsContainer = [Double]()
        let path = buildPathFromParts([rootPath, folder])
        for i in noteRange {
            forEachExampleInFile(String(i), path: path, label: labelFunction(i), numExamples: numNoteExamples, action: action)
        }
        print("Average RMS for files in folder \(folder): \(sum(rmsContainer)/Double(rmsContainer.count))")
    }

    func forEachExampleInFile(fileName: String, path: String, label: Int, numExamples: Int, action: Example -> ()) {
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

    func forEachExampleInFile(filePath: String, label: Int, numExamples: Int, action: Example -> ()) {
        let audioFile = AudioFile(filePath: filePath)!
        assert(audioFile.sampleRate == 44100)
        guard audioFile.readFrames(&data.0, count: sampleCount) == sampleCount else {
            return
        }
        
        var i = 0
        var dataContainer = [Double]()
        while i < numExamples {
            dataContainer.appendContentsOf(data.0)
            guard audioFile.readFrames(&data.1, count: sampleCount) == sampleCount else {
                print("Only able to retrieve \(i) examples from file \(filePath)")
                break
            }

            i += 1
            let example = Example(
                filePath: filePath,
                frameOffset: audioFile.currentFrame,
                label: label,
                data: data)
            action(example)

            audioFile.currentFrame -= sampleCount / 2
            swap(&data.0, &data.1)
        }
        
        print("Retrieved \(i) examples from (\(label)) \(filePath)")
        let fileRMS = rmsq(dataContainer)
        rmsContainer.append(fileRMS)
        print("RMS: \(fileRMS)")
    }
}
