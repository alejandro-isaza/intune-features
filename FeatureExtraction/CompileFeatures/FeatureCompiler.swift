//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

import AudioKit
import FeatureExtraction
import HDF5
import Surge

typealias Point = Surge.Point<Double>

class FeatureCompiler {
    let sampleRate = 44100
    let sampleCount: Int
    let notes = 36...96

    let fft: FFT
    let fb: Double

    init(sampleCount: Int) {
        self.sampleCount = sampleCount
        fft = FFT(inputLength: sampleCount)
        fb = Double(sampleRate) / Double(sampleCount)
    }
    
    func compileFeatures() {
        var trainingFeatures = [Example: [String: Feature]]()
        var testingFeatures = [Example: [String: Feature]]()

        let labelFunction: Int -> Int = { return $0 - self.notes.startIndex + 1 }
        let exampleBuilder = ExampleBuilder(noteRange: notes, sampleCount: sampleCount, labelFunction: labelFunction)
        exampleBuilder.forEachExample(training: { example in
            trainingFeatures[example] = self.generateFeatures(example)
        }, testing: { example in
            testingFeatures[example] = self.generateFeatures(example)
        })

        writeFeatures("training.h5", features: trainingFeatures)
        writeFeatures("testing.h5", features: testingFeatures)
    }
    
    func generateFeatures(example: Example) -> [String: Feature] {
        // Apply a random gain between 0.5 and 2.0
        let gain = exp2(Double(arc4random_uniform(2)) - 1.0)
        let data = example.data.map{ return $0 * gain }

        // Extract peaks
        let psd = sqrt(fft.forwardMags(data))
        let fftPoints = (0..<psd.count).map{ Point(x: fb * Double($0), y: psd[$0]) }
        let peaks = PeakExtractor.process(fftPoints).sort{ $0.y > $1.y }

        let rmsFeature = RMSFeature(audioData: data)
        let peakLocationsFeature = PeakLocationsFeature(peaks: peaks)
        let peakHeightsFeature = PeakHeightsFeature(peaks: peaks)
        let bandsFeature = BandsFeature(spectrum: psd, baseFrequency: fb)

        return [
            "rms": rmsFeature,
            "peak_frequencies": peakLocationsFeature,
            "peak_heights": peakHeightsFeature,
            "bands": bandsFeature
        ]
    }

    func writeFeatures(fileName: String, features: [Example: [String: Feature]]) {
        let featureData = FeatureData(features: features)
        writeFeatures(fileName, featureData: featureData)
    }

    func writeFeatures(fileName: String, featureData: FeatureData) {
        guard let hdf5File = HDF5.File.create(fileName, mode: File.CreateMode.Truncate) else {
            fatalError("Could not create HDF5 dataset.")
        }

        for (name, data) in featureData.data {
            let featureSize = UInt64(data.count / featureData.labels.count)
            let dataType = HDF5.Datatype.copy(type: .Double)
            let dataDataspace = Dataspace(dims: [UInt64(featureData.labels.count), UInt64(featureSize)])
            let dataDataset = HDF5.Dataset.create(file: hdf5File, name: name, datatype: dataType, dataspace: dataDataspace)
            dataDataset.writeDouble(data)
        }

        let labelType = HDF5.Datatype.copy(type: .Int)
        let labelDataspace = Dataspace(dims: [UInt64(featureData.labels.count)])
        let labelsDataset = HDF5.Dataset.create(file: hdf5File, name: "label", datatype: labelType, dataspace: labelDataspace)
        labelsDataset.writeInt(featureData.labels)
    }

}

