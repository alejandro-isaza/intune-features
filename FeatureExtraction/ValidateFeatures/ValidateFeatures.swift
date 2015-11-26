//
//  ValidateFeatures.swift
//  AudioFeatures
//
//  Created by Aidan Gomez on 2015-11-25.
//  Copyright © 2015 Venture Media. All rights reserved.
//

import Foundation
import Peak
import HDF5Kit
import FeatureExtraction

public class ValidateFeatures {
    let validateCount = 1000
    let sampleCount = 8 * 1024
    let sampleStep = 1024
    
    let HDF5File: File
    let labelDataset: Dataset<Int>
    let spectrumDataset: Dataset<Double>
    let locationsDataset: Dataset<Double>
    let heightsDataset: Dataset<Double>
    let fluxDataset: Dataset<Double>
    let fileNameDataset: Dataset<String>
    let offsetDataset: Dataset<Int>
    
    public init(filePath: String) {
        guard let HDF5File = File.open(filePath, mode: File.OpenMode.ReadOnly) else { fatalError() }
        
        self.HDF5File = HDF5File
        guard let label = HDF5File.openDataset("label", type: Int.self) else { fatalError() }
        self.labelDataset = label
        guard let offset = HDF5File.openDataset("offset", type: Int.self) else { fatalError() }
        self.offsetDataset = offset
        guard let fileName = HDF5File.openDataset("fileName", type: String.self) else { fatalError() }
        self.fileNameDataset = fileName
        
        guard let spectrum = HDF5File.openDataset("spectrum", type: Double.self) else { fatalError() }
        self.spectrumDataset = spectrum
        guard let locations = HDF5File.openDataset("peak_locations", type: Double.self) else { fatalError() }
        self.locationsDataset = locations
        guard let heights = HDF5File.openDataset("peak_heights", type: Double.self) else { fatalError() }
        self.heightsDataset = heights
        guard let flux = HDF5File.openDataset("spectrum_flux", type: Double.self) else { fatalError() }
        self.fluxDataset = flux
    }
    
    public func validate() -> Bool {
        let sampleCount = labelDataset.extent[0]
        let step = sampleCount / validateCount
        for i in 0..<validateCount {
            let index = i * step
            
            let fileName = String(fileNameDataset[index])
            
            guard let offset = offsetDataset[index, 0][0] as? Int else { fatalError() }
            
            let labelDim = labelDataset.extent[1]
            guard let label = labelDataset[index, 0..<labelDim] as? [Int] else { fatalError() }
            
            var example = Example(filePath: fileName, frameOffset: offset, label: label)
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
        
        file.currentFrame = example.frameOffset
        file.readFrames(example.data.0.mutablePointer, count: sampleCount)
        
        file.currentFrame = example.frameOffset + sampleStep
        file.readFrames(example.data.1.mutablePointer, count: sampleCount)
    }
    
    func compare(index: Int, featureBuilder: FeatureBuilder) -> Bool {
        let spectrumDim = spectrumDataset.extent[1]
        let spectrum = spectrumDataset[index, 0..<spectrumDim] as! [Double]

        let locationsDim = locationsDataset.extent[1]
        let locations = locationsDataset[index, 0..<locationsDim] as! [Double]

        let heightsDim = heightsDataset.extent[1]
        let heights = heightsDataset[index, 0..<heightsDim] as! [Double]

        let fluxDim = fluxDataset.extent[1]
        let flux = fluxDataset[index, 0..<fluxDim] as! [Double]

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
    
    func arraysMatch(lhs: [Double], rhs: BandsFeature) -> Bool {
        if lhs.count != rhs.data.count {
            return false
        }

        for i in 0..<lhs.count {
            if lhs[i] != rhs.data[i] {
                return false
            }
        }
        
        return true
    }
}