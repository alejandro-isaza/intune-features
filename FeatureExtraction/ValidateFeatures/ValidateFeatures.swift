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
        let validateCount = min(1000, featureDatabase.exampleCount)
        let step = featureDatabase.exampleCount / validateCount
        for i in 0..<validateCount {
            let index = i * step

            let feature = featureDatabase.readFeatures(index, count: 1).first!
            
            var example = Example(filePath: feature.filePath, frameOffset: feature.fileOffset, label: feature.label, data: (RealArray(count: FeatureBuilder.sampleCount), RealArray(count: FeatureBuilder.sampleCount)))
            loadExampleData(&example)
            
            let featureBuilder = FeatureBuilder()
            featureBuilder.generateFeatures(example)

            print("Validating '\(example.filePath)' offset \(example.frameOffset)...", terminator: "")
            if !compare(feature, featureBuilder) {
                print("Failed")
                print("Label \(example.label)")
                return false
            } else {
                print("Passed")
            }
        }
        return true
    }
    
    func loadExampleData(inout example: Example) {
        guard let file = AudioFile.open(example.filePath) else {
            fatalError("File not found '\(example.filePath)'")
        }
        
        readAtFrame(file, frame: example.frameOffset - FeatureBuilder.sampleCount / 2 - FeatureBuilder.sampleStep, data: example.data.0.mutablePointer)
        readAtFrame(file, frame: example.frameOffset - FeatureBuilder.sampleCount / 2, data: example.data.1.mutablePointer)
        //print("offset \(example.frameOffset) data \(example.data.1.description)")
    }
    
    func readAtFrame(file: AudioFile, frame: Int, data: UnsafeMutablePointer<Double>) {
        if frame >= 0 {
            file.currentFrame = frame
            file.readFrames(data, count: FeatureBuilder.sampleCount)
        } else {
            file.currentFrame = 0
            let fillSize = -frame
            for i in 0..<fillSize {
                data[i] = 0.0
            }
            file.readFrames(data + fillSize, count: FeatureBuilder.sampleCount - fillSize)
        }
    }
    
    func compare(feature: FeatureData, _ featureBuilder: FeatureBuilder) -> Bool {
        if !arraysMatch(feature.features[FeatureDatabase.spectrumDatasetName]!, rhs: featureBuilder.spectrumFeature1) {
            return false
        }
        if !arraysMatch(feature.features[FeatureDatabase.peakLocationsDatasetName]!, rhs: featureBuilder.peakLocations) {
            return false
        }
        if !arraysMatch(feature.features[FeatureDatabase.peakHeightsDatasetName]!, rhs: featureBuilder.peakHeights) {
            return false
        }
        if !arraysMatch(feature.features[FeatureDatabase.spectrumFluxDatasetName]!, rhs: featureBuilder.spectrumFluxFeature) {
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
                return false
            }
        }
        
        return true
    }
}
