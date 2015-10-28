//  Copyright © 2015 Venture Media. All rights reserved.

import Peak
import FeatureExtraction
import Foundation
import Upsurge

class MonoExampleBuilder {
    let rootPath = "../AudioData/Monophonic/"
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
        "VentureFast2",
        "VentureFast3",
        "VentureFast4",
        "VenturePianoQuiet2",
        "VenturePianoQuiet3",
        "VenturePianoQuiet4"
    ]
    let testingFolders = [
        "Arachno",
        "VentureFast1",
        "VenturePianoQuiet1"
    ]
    let testingNoiseFileName = "../Noise/testingnoise"
    let trainingNoiseFileName = "../Noise/trainingnoise"
    let foosNoiseFileName = "../Noise/foos"
    let fileExtensions = [
        "m4a",
        "caf",
        "wav",
        "aiff"
    ]
    
    let numNoteExamples = 15
    let numNoiseExamples = 1000

    let noteRange: Range<Int>
    let sampleCount: Int
    let labelFunction: [Int] -> [Int]
    let noiseLabel = [0]
    private var data: (RealArray, RealArray)

    private var rmsContainer = [Double]()
    
    init(noteRange: Range<Int>, sampleCount: Int, labelFunction: [Int] -> [Int] = { $0 }) {
        self.sampleCount = sampleCount
        self.noteRange = noteRange
        self.labelFunction = labelFunction
        data.0 = RealArray(count: sampleCount)
        data.1 = RealArray(count: sampleCount)
    }
    
    func forEachExample(training training: Example -> (), testing: Example -> ()) -> [String] {
        print("\nWorking Directory: \(NSFileManager.defaultManager().currentDirectoryPath)\n")
        for folder in trainingFolders {
            forEachExampleInFolder(folder, action: training)
        }
        for folder in testingFolders {
            forEachExampleInFolder(folder, action: testing)
        }

        forEachExampleInFile(trainingNoiseFileName, path: rootPath, label: noiseLabel, numExamples: numNoiseExamples, action: training)
        forEachExampleInFile(testingNoiseFileName, path: rootPath, label: noiseLabel, numExamples: numNoiseExamples, action: testing)
        forEachExampleInFile(foosNoiseFileName, path: rootPath, label: noiseLabel, numExamples: numNoiseExamples, action: training)
        
        return testingFolders + trainingFolders
    }
    
    func forEachExampleInFolder(folder: String, action: Example -> ()) {
        rmsContainer = [Double]()
        let path = buildPathFromParts([rootPath, folder])
        for i in noteRange {
            forEachExampleInFile(String(i), path: path, label: labelFunction([i]), numExamples: numNoteExamples, action: action)
        }
        print("Average RMS for files in folder \(folder): \(sum(rmsContainer)/Double(rmsContainer.count))\n\n")
    }

    func forEachExampleInFile(fileName: String, path: String, label: [Int], numExamples: Int, action: Example -> ()) {
        let fileManager = NSFileManager.defaultManager()
        for type in fileExtensions {
            let fullFileName = "\(fileName).\(type)"
            let filePath = buildPathFromParts([path, fullFileName])
            if fileManager.fileExistsAtPath(filePath) {
                print("Processing \(filePath) (label \(label))")
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

        rmsContainer.append(sqrt(sumsq/Double(count)))
    }
}
