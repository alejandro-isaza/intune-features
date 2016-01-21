//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Peak
import HDF5Kit
import FeatureExtraction
import Upsurge

public struct Label: Equatable {
    var eventNotes: [Note]
    var eventVelocities: [Double]
    
    init() {
        eventNotes = [Note]()
        eventVelocities = [Double]()
    }

    init(eventNotes: [Note], eventVelocities: [Double]) {
        self.eventNotes = eventNotes
        self.eventVelocities = eventVelocities
    }
}

public class ValidateFeatures {
    let labelBatch = 128
    
    let featureDatabase: FeatureDatabase
    
    public init(filePath: String) {
        featureDatabase = FeatureDatabase(filePath: filePath, overwrite: false)
    }
    
    public func validate() -> Bool {
        let validateCount = min(1000, featureDatabase.sequenceCount)
        let step = featureDatabase.sequenceCount / validateCount
        for i in 0..<validateCount {
            let index = i * step
            let sequence = try! featureDatabase.readSequenceAtIndex(index)

            print("Validating '\(sequence.filePath)' offset \(sequence.startOffset)...", terminator: "")
            if !validateSequence(sequence) {
                print("Failed: Features don't match")
                return false
            } else {
                print("Passed")
            }
        }
        return true
    }
    
    func validateSequence(sequence: Sequence) -> Bool {
        let filePath = sequence.filePath
        let featureBuilder = FeatureBuilder()

        for event in sequence.events {
            let offset = event.offset
            let featureIndex = (offset - sequence.startOffset) / FeatureBuilder.sampleStep
            let expectedFeature = sequence.features[featureIndex]
            let expectedLabel = Label(eventNotes: event.notes, eventVelocities: event.velocities)
            
            let data: (RealArray, RealArray) = (RealArray(count: FeatureBuilder.sampleCount), RealArray(count: FeatureBuilder.sampleCount))
            loadExampleData(filePath, offset: offset, data: data)
            let actualFeature = featureBuilder.generateFeatures(data.0, data.1)
            
            if !compareFeatures(expectedFeature, actualFeature) {
                return false
            }
            if !validateLabels(filePath, offset: offset, expectedLabel: expectedLabel) {
                return false
            }
        }
        
        return true
    }
    
    func validateLabels(filePath: String, offset: Int, expectedLabel: Label) -> Bool {
        if let actualLabel = polyLabel(filePath, offset: offset) {
            if actualLabel != actualLabel {
                print("Labels don't match. Expected \(expectedLabel.eventNotes.description) got \(actualLabel.eventNotes.description)")
                return false
            }
        } else if let actualLabel = monoLabel(filePath, offset: offset) {
            if expectedLabel != actualLabel {
                print("Labels don't match. Expected \(expectedLabel.eventNotes.description) got \(actualLabel.eventNotes.description)")
                return false
            }
        } else {
            if expectedLabel != Label() {
                print("Labels don't match. Expected \(expectedLabel.eventNotes.description) got \(Label().eventNotes.description)")
                return false
            }
        }
        
        return true
    }
    
    func loadExampleData(filePath: String, offset: Int, data: (RealArray, RealArray)) {
        guard let file = AudioFile.open(filePath) else {
            fatalError("File not found '\(filePath)'")
        }
        
        readAtFrame(file, frame: offset - FeatureBuilder.sampleCount / 2 - FeatureBuilder.sampleStep, data: data.0.mutablePointer)
        readAtFrame(file, frame: offset - FeatureBuilder.sampleCount / 2, data: data.1.mutablePointer)
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
    
    func compareFeatures(expectedFeature: Feature, _ actualFeature: Feature) -> Bool {
        let expectedSpectrum = expectedFeature.spectrum
        let actualSpectrum = actualFeature.spectrum
        if actualSpectrum != expectedSpectrum {
            print("Failed: Spectrum features don't match. Expected \(expectedSpectrum.description) got \(actualSpectrum.description)")
            return false
        }

        let expectedPeakLocations = expectedFeature.peakLocations
        let actualPeakLocations = actualFeature.peakLocations
        if actualPeakLocations != expectedPeakLocations {
            print("Failed: Peak location features don't match. Expected \(expectedPeakLocations.description) got \(actualPeakLocations.description)")
            return false
        }

        let expectedPeakHeights = expectedFeature.peakHeights
        let actualPeakHeights = actualFeature.peakHeights
        if actualPeakHeights != expectedPeakHeights {
            print("Failed: peak height features don't match. Expected \(expectedPeakHeights.description) got \(actualPeakHeights.description)")
            return false
        }

        let expectedFluxes = expectedFeature.spectralFlux
        let actualFluxes = actualFeature.spectralFlux
        if actualFluxes != expectedFluxes {
            print("Failed: spectrum flux features don't match. Expected \(expectedFluxes.description) got \(actualFluxes.description)")
            return false
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
        let label = Label(eventNotes: [note], eventVelocities: [0.75])

        return label
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
                
                label.eventNotes.append(Note(midiNoteNumber: Int(note.note)))
            }
            
            return label
        }
        
        return nil
    }
    
    func labelFromEvent(event: Sequence.Event) -> Label {
        return Label(eventNotes: event.notes, eventVelocities: event.velocities)
    }

}

public func ==(lhs: Label, rhs: Label) -> Bool {
    for (lhsNote, rhsNote) in zip(lhs.eventNotes, rhs.eventNotes) {
        if lhsNote != rhsNote {
            return false
        }
    }
    for (lhsVelocity, rhsVelocity) in zip(lhs.eventVelocities, rhs.eventVelocities) {
        if lhsVelocity != rhsVelocity {
            return false
        }
    }
    return true
}
