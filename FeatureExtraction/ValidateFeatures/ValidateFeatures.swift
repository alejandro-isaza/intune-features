//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Peak
import HDF5Kit
import FeatureExtraction
import Upsurge

public class ValidateFeatures {
    let validateCount = 1000
    
    let featureDatabase: FeatureDatabase
    
    public init(filePath: String) {
        featureDatabase = FeatureDatabase(filePath: filePath, overwrite: false)
    }
    
    public func validate() -> Bool {
        let labelDataset = featureDatabase.getIntTable("label")!
        let fileNameDataset = featureDatabase.getStringTable("fileName")!
        let offsetDataset = featureDatabase.getIntTable("offset")!
        
        let step = featureDatabase.exampleCount / validateCount
        for i in 0..<validateCount {
            let index = i * step
            
            let offset = featureDatabase.readIntTableData(offsetDataset, index: index)[0]
            let label = featureDatabase.readIntTableData(labelDataset, index: index)
            let fileName = featureDatabase.readStringTableData(fileNameDataset, index: index)
            
            var example = Example(filePath: fileName, frameOffset: offset, label: label, data: (RealArray(count: FeatureBuilder.sampleCount), RealArray(count: FeatureBuilder.sampleCount)))
            getData(&example)
            
            let featureBuilder = FeatureBuilder()
            featureBuilder.generateFeatures(example)
            
            if !compare(index, featureBuilder: featureBuilder) {
                return false
            }
        }
        return true
    }
    
    func getData(inout example: Example) {
        guard let file = AudioFile.open(example.filePath) else { fatalError() }
        
        readAtFrame(file, frame: example.frameOffset - FeatureBuilder.sampleCount / 2, data: example.data.0.mutablePointer)
        readAtFrame(file, frame: example.frameOffset - FeatureBuilder.sampleCount / 2 + FeatureBuilder.sampleStep, data: example.data.1.mutablePointer)
    }
    
    func readAtFrame(file: AudioFile, frame: Int, data: UnsafeMutablePointer<Double>) {
        if frame >= 0 {
            file.currentFrame = frame
            file.readFrames(data, count: FeatureBuilder.sampleCount)
        } else {
            file.currentFrame = 0
            file.readFrames(data - frame, count: FeatureBuilder.sampleCount + frame)
        }
    }
    
    func compare(index: Int, featureBuilder: FeatureBuilder) -> Bool {
        let spectrumTable = featureDatabase.getDoubleTable("spectrum")!
        let locationsTable = featureDatabase.getDoubleTable("peak_locations")!
        let heightsTable = featureDatabase.getDoubleTable("peak_heights")!
        let fluxTable = featureDatabase.getDoubleTable("spectrum_flux")!
        
        let spectrum = featureDatabase.readDoubleTableData(spectrumTable, index: index)
        let locations = featureDatabase.readDoubleTableData(locationsTable, index: index)
        let heights = featureDatabase.readDoubleTableData(heightsTable, index: index)
        let flux = featureDatabase.readDoubleTableData(fluxTable, index: index)
        
        if !arraysMatch(spectrum, rhs: featureBuilder.spectrumFeature0) {
            return false
        } else if !arraysMatch(locations, rhs: featureBuilder.peakLocations) {
            return false
        } else if !arraysMatch(heights, rhs: featureBuilder.peakHeights) {
            return false
        } else if !arraysMatch(flux, rhs: featureBuilder.spectrumFluxFeature) {
            return false
        }
        
        return true
    }
    
    func arraysMatch(lhs: RealArray, rhs: BandsFeature) -> Bool {
        if lhs.count != rhs.data.count {
            return false
        }

        for i in 0..<lhs.count {
            if lhs[i] != rhs.data[i] {
                print(lhs[i], rhs.data[i])
            }
        }
        
        return true
    }
}