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
import Upsurge

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
        let exampleCount = labelDataset.extent[0]
        let step = exampleCount / validateCount
        for i in 0..<validateCount {
            let index = i * step
            
            let space = Dataspace(fileNameDataset.space)
            space.select(index)
            let fileName = fileNameDataset.readString(fileSpace: space)[0]
            
            var fileSpace = Dataspace(offsetDataset.space)
            fileSpace.select(index)
            var memSpace = Dataspace(dims: [1, 0])
            var offset = Int()
            offsetDataset.readInt(&offset, memSpace: memSpace, fileSpace: fileSpace)
            
            let labelDim = labelDataset.extent[1]
            fileSpace = Dataspace(labelDataset.space)
            let sel = HyperslabIndex(start: 0, count: labelDim)
            fileSpace.select(index, sel)
            memSpace = Dataspace(dims: [1, labelDim])
            var label = [Int](count: labelDim, repeatedValue: 0)
            labelDataset.readInt(&label, memSpace: memSpace, fileSpace: fileSpace)

            var example = Example(filePath: fileName, frameOffset: offset, label: label, data: (RealArray(count: sampleCount), RealArray(count: sampleCount)))
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
        
        readAtFrame(file, frame: example.frameOffset - sampleCount / 2, data: example.data.0.mutablePointer)
        readAtFrame(file, frame: example.frameOffset - sampleCount / 2 + sampleStep, data: example.data.1.mutablePointer)
    }
    
    func readAtFrame(file: AudioFile, frame: Int, data: UnsafeMutablePointer<Double>) {
        if frame >= 0 {
            file.currentFrame = frame
            file.readFrames(data, count: sampleCount)
        } else {
            file.currentFrame = 0
            file.readFrames(data - frame, count: sampleCount + frame)
        }
    }
    
    func compare(index: Int, featureBuilder: FeatureBuilder) -> Bool {
        var dim = spectrumDataset.extent[1]
        var fileSpace = Dataspace(spectrumDataset.space)
        var sel = HyperslabIndex(start: 0, count: dim)
        fileSpace.select(index, sel)
        var memSpace = Dataspace(dims: [1, dim])
        var spectrum = [Double](count: dim, repeatedValue: 0)
        spectrumDataset.readDouble(&spectrum, memSpace: memSpace, fileSpace: fileSpace)

        dim = locationsDataset.extent[1]
        fileSpace = Dataspace(locationsDataset.space)
        sel = HyperslabIndex(start: 0, count: dim)
        fileSpace.select(index, sel)
        memSpace = Dataspace(dims: [1, dim])
        var locations = [Double](count: dim, repeatedValue: 0)
        locationsDataset.readDouble(&locations, memSpace: memSpace, fileSpace: fileSpace)

        dim = heightsDataset.extent[1]
        fileSpace = Dataspace(heightsDataset.space)
        sel = HyperslabIndex(start: 0, count: dim)
        fileSpace.select(index, sel)
        memSpace = Dataspace(dims: [1, dim])
        var heights = [Double](count: dim, repeatedValue: 0)
        heightsDataset.readDouble(&heights, memSpace: memSpace, fileSpace: fileSpace)

        dim = fluxDataset.extent[1]
        fileSpace = Dataspace(fluxDataset.space)
        sel = HyperslabIndex(start: 0, count: dim)
        fileSpace.select(index, sel)
        memSpace = Dataspace(dims: [1, dim])
        var flux = [Double](count: dim, repeatedValue: 0)
        fluxDataset.readDouble(&flux, memSpace: memSpace, fileSpace: fileSpace)

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
                print(lhs[i], rhs.data[i])
            }
        }
        
        return true
    }
}