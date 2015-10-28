//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

import Peak
import FeatureExtraction
import HDF5Kit
import Upsurge

class PolyFeatureCompiler {
    var featureBuilder = FeatureBuilder()

    let trainingFileName = "training.h5"
    let testingFileName = "testing.h5"

    func compileFeatures() {
        let existingFolders = loadExistingFolders()
        var trainingFeatures = [FeatureData]()
        var testingFeatures = [FeatureData]()
        
        let exampleBuilder = PolyExampleBuilder(sampleCount: FeatureBuilder.sampleCount, sampleStep: FeatureBuilder.sampleStep, existingFolders: existingFolders)
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

    func loadExistingFolders() -> [String] {
        var existingFolders = [String]()
        if let folders = getFolders(trainingFileName) {
            existingFolders.appendContentsOf(folders)
        }
        if let folders = getFolders(testingFileName) {
            existingFolders.appendContentsOf(folders)
        }
        return existingFolders
    }

    func getFolders(fileName: String) -> [String]? {
        let hdf5File = HDF5Kit.File.open(fileName, mode: File.OpenMode.ReadWrite)
        return hdf5File?.openDataset("folders")?.readString()
    }
    
    func loadExistingData(hdf5File: HDF5Kit.File) -> [FeatureData] {
        var labels = [[Int]]()
        for i in 0..<FeatureBuilder.notes.count {
            labels.append(readIntDataset(hdf5File, datasetName: "label\(i)"))
        }
        let offsets = readIntDataset(hdf5File, datasetName: "offset")
        let fileNames = readStringDataset(hdf5File, datasetName: "fileName")
        
        let rms = readRealDataset(hdf5File, datasetName: "rms")
        let peakLocations = readRealDataset(hdf5File, datasetName: "peak_locations")
        let peakHeights = readRealDataset(hdf5File, datasetName: "peak_heights")
        let bands = readRealDataset(hdf5File, datasetName: "bands")
        let bandFluxes = readRealDataset(hdf5File, datasetName: "band_fluxes")
        
        var examples = [FeatureData]()
        for i in 0..<offsets.count {
            let rmsCount = rms.count / offsets.count
            let peakLocationsCount = peakLocations.count / offsets.count
            let peakHeightsCount = peakHeights.count / offsets.count
            let bandsCount = bands.count / offsets.count
            let bandFluxesCount = bandFluxes.count / offsets.count

            let features = [
                "rms": RealArray(rms[i*rmsCount..<(i+1)*rmsCount]),
                "peak_locations": RealArray(peakLocations[i*peakLocationsCount..<(i+1)*peakLocationsCount]),
                "peak_heights": RealArray(peakHeights[i*peakHeightsCount..<(i+1)*peakHeightsCount]),
                "bands": RealArray(bands[i*bandsCount..<(i+1)*bandsCount]),
                "band_fluxes": RealArray(bandFluxes[i*bandFluxesCount..<(i+1)*bandFluxesCount])
            ]
            
            let example = Example(filePath: fileNames[i], frameOffset: offsets[i], label: labels[i])
            examples.append(FeatureData(example: example, features: features))
        }
        
        return examples
    }
    
    func readIntDataset(hdf5File: HDF5Kit.File, datasetName: String) -> [Int] {
        guard let dataset = hdf5File.openDataset(datasetName) else {
            fatalError("HDF5 has no '\(datasetName)' dataset")
        }
        
        var data = [Int](count: Int(dataset.space.size), repeatedValue: 0)
        guard dataset.readInt(&data) == true else {
            fatalError("Could not read dataset from HDF5 file")
        }
        return data
    }
    
    func readRealDataset(hdf5File: HDF5Kit.File, datasetName: String) -> RealArray {
        guard let dataset = hdf5File.openDataset(datasetName) else {
            fatalError("HDF5 has no '\(datasetName)' dataset")
        }
        
        let data = RealArray(count: Int(dataset.space.size), repeatedValue: 0)
        guard dataset.readDouble(data.mutablePointer) == true else {
            fatalError("Could not read dataset from HDF5 file")
        }
        return data
    }
    
    func readStringDataset(hdf5File: HDF5Kit.File, datasetName: String) -> [String] {
        guard let stringData = hdf5File.openDataset(datasetName)?.readString() else {
            fatalError("HDF5 has no '\(datasetName)' dataset")
        }
        return stringData
    }
}
