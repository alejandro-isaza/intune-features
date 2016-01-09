//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Peak
import HDF5Kit
import FeatureExtraction
import Upsurge

public class ValidateFeatures {
    let validateCount = 1000
    let labelBatch = 128
    let repeatLabelThreshold = 5
    
    let featureDatabase: FeatureDatabase
    
    public init(filePath: String) {
        featureDatabase = FeatureDatabase(filePath: filePath, overwrite: false)
    }
    
    public func validate() -> Bool {
        let validateCount = min(1000, featureDatabase.exampleCount)
        let step = featureDatabase.exampleCount / validateCount
        for i in 0..<validateCount {
            let index = i * step
            let count = min(labelBatch, featureDatabase.exampleCount - index)
            
            let features = featureDatabase.readFeatures(index, count: count)
            let feature = features[0]

            let data0 = RealArray(count: FeatureBuilder.sampleCount, repeatedValue: 0)
            let data1 = RealArray(count: FeatureBuilder.sampleCount, repeatedValue: 0)
            var example = Example(filePath: feature.filePath, frameOffset: feature.fileOffset, label: feature.label, data: (data0, data1))
            loadExampleData(&example)
            
            let featureBuilder = FeatureBuilder()
            featureBuilder.generateFeatures(example.data.0, example.data.1) // Ignore return value, features will be preserved in the feature builder
            
            print("Validating '\(example.filePath)' offset \(example.frameOffset) (\(feature.label.description))...", terminator: "")
            if !compare(feature, featureBuilder) {
                print("Failed: Features don't match")
                return false
            } else if !shufflingCheck(features) {
                print("Failed: Data not sufficiently shuffled")
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
    
    func shufflingCheck(features: [FeatureData]) -> Bool {
        var occurances = [Label: Int]()
        for feature in features {
            if let count = occurances[feature.label] {
                occurances.updateValue(count + 1, forKey: feature.label)
            } else {
                occurances[feature.label] = 1
            }
        }
        
        let max = occurances.maxElement{ $0.0.1 >= $0.1.1 }!
        if max.1 > repeatLabelThreshold {
            print("A label occurred \(max.1) times")
            return false
        } else {
            return true
        }
    }
    
    func compare(feature: FeatureData, _ featureBuilder: FeatureBuilder) -> Bool {
        let expectedSpectrum = featureBuilder.spectrumFeature1
        let actualSpectrum = feature.features[FeatureDatabase.spectrumDatasetName]!
        if !arraysMatch(actualSpectrum, rhs: expectedSpectrum) {
            print("Failed: Spectrum features don't match. Expected \(expectedSpectrum.data.description) got \(actualSpectrum.description)")
            return false
        }

        let expectedPeakLocations = featureBuilder.peakLocations
        let actualPeakLocations = feature.features[FeatureDatabase.peakLocationsDatasetName]!
        if !arraysMatch(actualPeakLocations, rhs: expectedPeakLocations) {
            print("Failed: Peak location features don't match. Expected \(expectedPeakLocations.data.description) got \(actualPeakLocations.description)")
            return false
        }

        let expectedPeakHeights = featureBuilder.peakHeights
        let actualPeakHeights = feature.features[FeatureDatabase.peakHeightsDatasetName]!
        if !arraysMatch(actualPeakHeights, rhs: expectedPeakHeights) {
            print("Failed: peak height features don't match. Expected \(expectedPeakHeights.data.description) got \(actualPeakHeights.description)")
            return false
        }

        let expectedFluxes = featureBuilder.spectrumFluxFeature
        let actualFluxes = feature.features[FeatureDatabase.spectrumFluxDatasetName]!
        if !arraysMatch(actualFluxes, rhs: expectedFluxes) {
            print("Failed: spectrum flux features don't match. Expected \(expectedFluxes.data.description) got \(actualFluxes.description)")
            return false
        }

        if let label = polyLabel(feature.filePath, offset: feature.fileOffset) {
            if feature.label != label {
                print("Labels don't match. Expected \(label.description) got \(feature.label.description)")
                return false
            }
        } else if let label = monoLabel(feature.filePath, offset: feature.fileOffset) {
            if feature.label != label {
                print("Labels don't match. Expected \(label.description) got \(feature.label.description)")
                return false
            }
        } else {
            if feature.label != Label() {
                print("Labels don't match. Expected \(Label().description) got \(feature.label.description)")
                return false
            }
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
    
    func monoLabel(path: String, offset: Int) -> Label? {
        let monophonicFileExpression = try! NSRegularExpression(pattern: "/(\\d+)\\.\\w+", options: NSRegularExpressionOptions.CaseInsensitive)
        guard let results = monophonicFileExpression.firstMatchInString(path, options: NSMatchingOptions.ReportCompletion, range: NSMakeRange(0, path.characters.count)) else {
            return nil
        }
        if results.numberOfRanges < 1 {
            return nil
        }
        let range = results.rangeAtIndex(1)
        
        let fileName = (path as NSString).substringWithRange(range)
        guard let noteNumber = Int(fileName) else {
            return nil
        }
        
        let note = Note(midiNoteNumber: noteNumber)
        let time = Double(offset) / FeatureBuilder.samplingFrequency

        return Label(note: note, atTime: time)
    }
    
    func polyLabel(path: String, offset: Int) -> Label? {
        let manager = NSFileManager.defaultManager()
        let url = NSURL.fileURLWithPath(path)
        guard let midFileURL = url.URLByDeletingPathExtension?.URLByAppendingPathExtension("mid") else {
            fatalError("Failed to build path")
        }
        
        if manager.fileExistsAtPath(midFileURL.path!) {
            let midFile = Peak.MIDIFile(filePath: midFileURL.path!)!
            
            // Time in seconds for the middle of the current window
            let time = Double(offset) / FeatureBuilder.samplingFrequency
            
            // Discard margin in seconds
            let margin = (1.0 / 8.0) * Double(FeatureBuilder.sampleCount) / FeatureBuilder.samplingFrequency
            
            let offsetStart = offset - FeatureBuilder.sampleCount / 2
            let timeStart = margin + Double(offsetStart) / FeatureBuilder.samplingFrequency
            let beatStart = midFile.beatsForSeconds(timeStart)
            
            let offsetEnd = offset + FeatureBuilder.sampleCount / 2
            let timeEnd = Double(offsetEnd) / FeatureBuilder.samplingFrequency - margin
            let beatEnd = midFile.beatsForSeconds(timeEnd)
            
            var label = Label()
            for note in midFile.noteEvents {
                let noteStart = note.timeStamp
                let noteEnd = noteStart + Double(note.duration)
                
                // Ignore note events before the current window
                if noteEnd < beatStart {
                    continue
                }
                
                // Stop at the first note past the current window
                if noteStart > beatEnd {
                    break
                }
                
                let noteStartTime = midFile.secondsForBeats(noteStart)
                label.addNote(Note(midiNoteNumber: Int(note.note)), atTime: noteStartTime - time)
            }
            
            return label
        }
        
        return nil
    }

}
