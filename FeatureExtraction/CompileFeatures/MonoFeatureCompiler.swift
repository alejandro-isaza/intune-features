//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

import Peak
import FeatureExtraction
import HDF5Kit
import Upsurge

func midiNoteLabel(notes: Range<Int>, note: Int) -> Int {
    return note - notes.startIndex + 1
}

class MonoFeatureCompiler {
    let rootPath = "../AudioData/Monophonic/"
    let testingFolders = [
        "Arachno",
        "VenturePianoQuiet1",
        "VentureFast1"
    ]

    let trainingFileName = "training.h5"
    let testingFileName = "testing.h5"

    var featureBuilder = FeatureBuilder()

    func compileFeatures() {
        let trainingDatabase = FeatureDatabase(filePath: trainingFileName, overwrite: false)
        let testingDatabase = FeatureDatabase(filePath: testingFileName, overwrite: false)
        var existingFolders = trainingDatabase.folders + testingDatabase.folders
        let folders = loadFolders()

        let exampleBuilder = MonoExampleBuilder(sampleCount: FeatureBuilder.sampleCount, sampleStep: FeatureBuilder.sampleStep)
        for folder in folders {
            let name = (folder as NSString).lastPathComponent
            if existingFolders.contains(name) {
                continue
            }

            var features = [FeatureData]()
            exampleBuilder.forEachExampleInFolder(folder, action: { example in
                let featureData = FeatureData(example: example)
                featureData.features = self.featureBuilder.generateFeatures(example)
                features.append(featureData)
            })

            if testingFolders.contains(name) {
                testingDatabase.appendFeatures(features, folder: name)
            } else {
                trainingDatabase.appendFeatures(features, folder: name)
            }

            existingFolders.append(name)
        }
    }

    func loadFolders() -> [String] {
        print("\nWorking Directory: \(NSFileManager.defaultManager().currentDirectoryPath)\n")

        let fileManager = NSFileManager.defaultManager()
        guard let folders = try? fileManager.contentsOfDirectoryAtURL(NSURL.fileURLWithPath(rootPath), includingPropertiesForKeys: [NSURLNameKey], options: NSDirectoryEnumerationOptions.SkipsHiddenFiles) else {
            fatalError()
        }
        return folders.map{ $0.path! }
    }
}
