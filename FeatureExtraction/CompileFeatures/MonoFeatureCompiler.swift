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
    var featureBuilder = FeatureBuilder()

    let trainingFileName = "training.h5"
    let testingFileName = "testing.h5"

    func compileFeatures() {
        var trainingFeatures = [FeatureData]()
        var testingFeatures = [FeatureData]()
        
        let exampleBuilder = MonoExampleBuilder(noteRange: FeatureBuilder.notes, sampleCount: FeatureBuilder.sampleCount, labelFunction: FeatureBuilder.labelFunction)
        let folders = exampleBuilder.forEachExample(training: { example in
            let featureData = FeatureData(example: example)
            featureData.features = self.featureBuilder.generateFeatures(example)
            trainingFeatures.append(featureData)
        }, testing: { example in
            let featureData = FeatureData(example: example)
            featureData.features = self.featureBuilder.generateFeatures(example)
            testingFeatures.append(featureData)
        })

        FeatureDataCompiler(features: trainingFeatures).writeToHDF5(trainingFileName, noteRange: FeatureBuilder.notes, folders: folders)
        FeatureDataCompiler(features: testingFeatures).writeToHDF5(testingFileName, noteRange: FeatureBuilder.notes, folders: folders)
    }
}
