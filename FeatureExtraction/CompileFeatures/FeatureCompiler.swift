//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

import Peak
import FeatureExtraction
import HDF5Kit
import Upsurge

func midiNoteLabel(notes: Range<Int>, note: Int) -> Int {
    return note - notes.startIndex + 1
}

func octaveNoteLabel(note: Int) -> Int {
    return noteComponents(note).1.rawValue + 1
}

class FeatureCompiler {
    // Basic parameters
    static let sampleRate = 44100
    static let sampleCount = 8*1024
    static let labelFunction: Int -> Int = { midiNoteLabel(notes, note: $0) }

    // Notes and bands parameters
    static let notes = 36...96
    static let bandNotes = 24...120
    static let bandSize = 1.0

    // Peaks parameters
    static let peakHeightCutoff = 0.0005
    static let peakMinimumNoteDistance = 0.5

    // Output parameters
    static let trainingFileName = "training.h5"
    static let testingFileName = "testing.h5"


    // Helpers
    let window = RealArray(count: FeatureCompiler.sampleCount)
    let fft = FFT(inputLength: FeatureCompiler.sampleCount)
    let peakExtractor = PeakExtractor(heightCutoff: FeatureCompiler.peakHeightCutoff, minimumNoteDistance: FeatureCompiler.peakMinimumNoteDistance)
    let fb = Double(FeatureCompiler.sampleRate) / Double(FeatureCompiler.sampleCount)

    // Features
    let rms: RMSFeature = RMSFeature()
    let peakLocations: PeakLocationsFeature = PeakLocationsFeature(notes: FeatureCompiler.bandNotes, bandSize: FeatureCompiler.bandSize)
    let peakHeights: PeakHeightsFeature = PeakHeightsFeature(notes: FeatureCompiler.bandNotes, bandSize: FeatureCompiler.bandSize)
    let bands0: SpectrumFeature = SpectrumFeature(notes: FeatureCompiler.bandNotes, bandSize: FeatureCompiler.bandSize)
    let bands1: SpectrumFeature = SpectrumFeature(notes: FeatureCompiler.bandNotes, bandSize: FeatureCompiler.bandSize)
    let bandFluxes: BandFluxsFeature = BandFluxsFeature(notes: FeatureCompiler.bandNotes, bandSize: FeatureCompiler.bandSize)


    init() {
        vDSP_hamm_windowD(window.pointer, vDSP_Length(FeatureCompiler.sampleCount), 0)
    }
    
    func compileFeatures() {
        var trainingFeatures = [Example: [String: RealArray]]()
        var testingFeatures = [Example: [String: RealArray]]()

        let exampleBuilder = ExampleBuilder(noteRange: FeatureCompiler.notes, sampleCount: FeatureCompiler.sampleCount, labelFunction: FeatureCompiler.labelFunction)
        exampleBuilder.forEachExample(training: { example in
            trainingFeatures[example] = self.generateFeatures(example)
        }, testing: { example in
            testingFeatures[example] = self.generateFeatures(example)
        })

        writeFeatures(FeatureCompiler.trainingFileName, features: trainingFeatures)
        writeFeatures(FeatureCompiler.testingFileName, features: testingFeatures)
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
        let peaks1 = peakExtractor.process(points1).sort{ $0.y > $1.y }

        rms.update(data1)
        peakLocations.update(peaks1)
        peakHeights.update(peaks1, rms: rms.rms)
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
        return sqrt(fft.forwardMags(data * window))
    }

    /// Convert from spectrum values to frequency, value points
    func spectrumPoints(spectrum: RealArray) -> [Point] {
        return (0..<spectrum.count).map{ Point(x: fb * Real($0), y: spectrum[$0]) }
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
