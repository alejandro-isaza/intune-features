//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Peak
import HDF5Kit
import FeatureExtraction
import Upsurge

public struct Label: Equatable {
    var notes: [Note]
    var velocities: [Float]
    var onset: Float

    init() {
        notes = [Note]()
        velocities = [Float]()
        onset = 0.0
    }

    init(notes: [Note], velocities: [Float], onset: Float) {
        self.notes = notes
        self.velocities = velocities
        self.onset = onset
    }
}

public class ValidateFeatures {
    let labelBatch = 128

    let featureDatabase: FeatureDatabase
    let featureBuilder = FeatureBuilder()

    public init(filePath: String) {
        featureDatabase = FeatureDatabase(filePath: filePath, overwrite: false)
    }

    public func validate() -> Bool {
        let validateCount = min(500, featureDatabase.sequenceCount)
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
        let data: (ValueArray<Double>, ValueArray<Double>) = (ValueArray<Double>(count: FeatureBuilder.windowSize), ValueArray<Double>(count: FeatureBuilder.windowSize))

        for (i, expectedFeature) in sequence.features.enumerate() {
            let offset = sequence.startOffset + i * FeatureBuilder.stepSize

            var expectedLabel: Label
            if let eventIndex = sequence.events.indexOf({ $0.offset == offset }) {
                let event = sequence.events[eventIndex]
                expectedLabel = Label(notes: event.notes, velocities: event.velocities, onset: sequence.featureOnsetValues[i])
            } else {
                expectedLabel = Label()
                expectedLabel.onset = sequence.featureOnsetValues[i]
            }
            
            loadExampleData(filePath, offset: offset, data: data)
            let actualFeature = featureBuilder.generateFeatures(data.0, data.1)

            if !compareFeatures(expectedFeature, actualFeature) {
                return false
            }
            if !validateLabels(filePath, offset: offset, expectedLabel: expectedLabel, sequence: sequence) {
                return false
            }
        }

        return true
    }

    func validateLabels(filePath: String, offset: Int, expectedLabel: Label, sequence: Sequence) -> Bool {
        if let actualLabel = polyLabel(filePath, offset: offset, sequence: sequence) {
            if actualLabel != actualLabel {
                print("Labels don't match. Expected \(expectedLabel.notes.description) got \(actualLabel.notes.description)")
                return false
            }
        } else if let actualLabel = monoLabel(filePath, offset: offset) {
            if expectedLabel != actualLabel {
                print("Labels don't match. Expected \(expectedLabel.notes.description) got \(actualLabel.notes.description)")
                return false
            }
        } else {
            if expectedLabel != Label() {
                print("Labels don't match. Expected \(expectedLabel.notes.description) got \(Label().notes.description)")
                return false
            }
        }

        return true
    }

    func loadExampleData(filePath: String, offset: Int, data: (ValueArray<Double>, ValueArray<Double>)) {
        guard let file = AudioFile.open(filePath) else {
            fatalError("File not found '\(filePath)'")
        }

        readAtFrame(file, frame: offset, data: data.0.mutablePointer)
        readAtFrame(file, frame: offset + FeatureBuilder.stepSize, data: data.1.mutablePointer)
    }

    func readAtFrame(file: AudioFile, frame: Int, data: UnsafeMutablePointer<Double>) {
        if frame >= 0 {
            file.currentFrame = frame
            guard let read = file.readFrames(data, count: FeatureBuilder.windowSize) else {
                fatalError("Failed to read audio data")
            }
            for i in read..<FeatureBuilder.windowSize {
                data[i] = 0.0
            }
        } else {
            file.currentFrame = 0
            let fillSize = -frame
            for i in 0..<fillSize {
                data[i] = 0.0
            }

            let readCount = FeatureBuilder.windowSize - fillSize
            if readCount > 0 {
                guard let read = file.readFrames(data + fillSize, count: readCount) else {
                    fatalError("Failed to read audio data")
                }
                for i in fillSize + read..<FeatureBuilder.windowSize {
                    data[i] = 0.0
                }
            }
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

        let onsetIndexInWindow = FeatureBuilder.windowSize - offset
        let label: Label
        if onsetIndexInWindow >= 0 && onsetIndexInWindow < featureBuilder.window.count {
            let note = Note(midiNoteNumber: noteNumber)
            let onset = Float(featureBuilder.window[onsetIndexInWindow])
            let velocity = Float(0.75)

            label = Label(notes: [note], velocities: [velocity], onset: onset)
        } else {
            label = Label()
        }

        return label
    }

    func polyLabel(path: String, offset: Int, sequence: Sequence) -> Label? {
        let manager = NSFileManager.defaultManager()
        let url = NSURL.fileURLWithPath(path)
        guard let midFileURL = url.URLByDeletingPathExtension?.URLByAppendingPathExtension("mid") else {
            fatalError("Failed to build path")
        }

        if manager.fileExistsAtPath(midFileURL.path!) {
            let midFile = Peak.MIDIFile(filePath: midFileURL.path!)!

            // Discard margin in seconds
            let margin = (1.0 / 8.0) * Double(FeatureBuilder.windowSize) / FeatureBuilder.samplingFrequency

            let offsetStart = offset - FeatureBuilder.windowSize / 2
            let timeStart = margin + Double(offsetStart) / FeatureBuilder.samplingFrequency
            let beatStart = midFile.beatsForSeconds(timeStart)

            let offsetEnd = offset + FeatureBuilder.windowSize / 2
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

                label.notes.append(Note(midiNoteNumber: Int(note.note)))
                label.velocities.append(Float(note.velocity))
            }

            label.onset = onsetValueForWindowAt(offset, events: sequence.events)

            return label
        }

        return nil
    }

    func labelFromEvent(offset: Int, targetEventIndex: Int, events: [Sequence.Event]) -> Label {
        return Label(notes: events[targetEventIndex].notes, velocities: events[targetEventIndex].velocities, onset: onsetValueForWindowAt(offset, events: events))
    }

    func onsetValueForWindowAt(windowStart: Int, events: [Sequence.Event]) -> Float {
        var value = Float(0.0)
        for event in events {
            let index = event.offset - windowStart
            if index >= 0 && index < featureBuilder.window.count {
                value += Float(featureBuilder.window[index])
            }
        }
        return value
    }

}

public func ==(lhs: Label, rhs: Label) -> Bool {
    for (lhsNote, rhsNote) in zip(lhs.notes, rhs.notes) {
        if lhsNote != rhsNote {
            return false
        }
    }
    for (lhsVelocity, rhsVelocity) in zip(lhs.velocities, rhs.velocities) {
        if lhsVelocity != rhsVelocity {
            return false
        }
    }
    return true
}
