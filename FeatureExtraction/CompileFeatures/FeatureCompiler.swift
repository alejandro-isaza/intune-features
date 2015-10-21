//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

import Peak
import FeatureExtraction
import HDF5Kit
import Upsurge

typealias Point = Upsurge.Point<Double>

class FeatureCompiler {
    let sampleRate = 44100
    let sampleCount: Int
    let notes = 36...96

    let fft: FFT
    let fb: Double


    let rms = RMSFeature()
    let peakLocations = PeakLocationsFeature()
    let peakHeights = PeakHeightsFeature()
    let bands0 = SpectrumFeature()
    let bands1 = SpectrumFeature()
    let bandFluxes = BandFluxsFeature()

    init(sampleCount: Int) {
        self.sampleCount = sampleCount
        fft = FFT(inputLength: sampleCount)
        fb = Double(sampleRate) / Double(sampleCount)
    }
    
    func compileFeatures() {
        var trainingFeatures = [Example: [String: RealArray]]()
        var testingFeatures = [Example: [String: RealArray]]()

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
    
    func generateFeatures(example: Example) -> [String: RealArray] {
        // Apply a random gain between 0.5 and 2.0
        let gain = exp2(Double(arc4random_uniform(2)) - 1.0)
        let data0 = RealArray(example.data.0.map{ return $0 * gain })
        let data1 = RealArray(example.data.1.map{ return $0 * gain })

        // Previous spectrum
        let spectrum0 = spectrumValues(data0)

        // Extract peaks
        let spectrum1 = spectrumValues(data1)
        let points1 = spectrumPoints(spectrum1)
        let peaks1 = PeakExtractor.process(points1).sort{ $0.y > $1.y }

        rms.update(data1)
        peakLocations.update(peaks1)
        peakHeights.update(peaks1)
        bands0.update(spectrum: spectrum0, baseFrequency: fb)
        bands1.update(spectrum: spectrum1, baseFrequency: fb)
        bandFluxes.update(bands0: bands0.data, bands1: bands1.data)

        return [
            "rms": rms.data.copy(),
            "peak_locations": peakLocations.data.copy(),
            "peak_heights": peakHeights.data.copy(),
            "bands": bands1.data.copy(),
            "band_fluxes": bandFluxes.data.copy()
        ]
    }

    /// Compute the power spectrum values
    func spectrumValues(data: RealArray) -> RealArray {
        return sqrt(fft.forwardMags(data))
    }

    /// Convert from spectrum values to frequency, value points
    func spectrumPoints(spectrum: RealArray) -> [Point] {
        return (0..<spectrum.count).map{ Point(x: fb * Double($0), y: spectrum[$0]) }
    }

    func writeFeatures(fileName: String, features: [Example: [String: RealArray]]) {
        let featureData = FeatureData(features: features)
        writeFeatures(fileName, featureData: featureData)
    }

    func writeFeatures(fileName: String, featureData: FeatureData) {
        guard let hdf5File = HDF5Kit.File.create(fileName, mode: File.CreateMode.Truncate) else {
            fatalError("Could not create HDF5 dataset.")
        }

        for (name, data) in featureData.data {
            let featureSize = UInt64(data.count / featureData.labels.count)
            let dataType = Datatype.copy(type: .Double)
            let dataDataspace = Dataspace(dims: [UInt64(featureData.labels.count), UInt64(featureSize)])
            let dataDataset = Dataset.create(file: hdf5File, name: name, datatype: dataType, dataspace: dataDataspace)
            dataDataset.writeDouble([Double](data))
        }

        let labelType = HDF5Kit.Datatype.copy(type: .Int)
        let labelDataspace = Dataspace(dims: [UInt64(featureData.labels.count)])
        let labelsDataset = HDF5Kit.Dataset.create(file: hdf5File, name: "label", datatype: labelType, dataspace: labelDataspace)
        labelsDataset.writeInt(featureData.labels)
    }

}

