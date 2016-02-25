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
    var polyphony: Float

    init() {
        notes = [Note]()
        velocities = [Float]()
        onset = 0.0
        polyphony = 0.0
    }

    init(notes: [Note], velocities: [Float], onset: Float, polyphony: Float) {
        self.notes = notes
        self.velocities = velocities
        self.onset = onset
        self.polyphony = polyphony
    }
}

public class ValidateFeatures {
    let labelBatch = 128
    let windowSize: Int

    let featureDatabase: FeatureDatabase
    let featureBuilder: FeatureBuilder

    public init(filePath: String, windowSize: Int) {
        self.windowSize = windowSize
        featureBuilder = FeatureBuilder(windowSize: windowSize)
        featureDatabase = FeatureDatabase(filePath: filePath)
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
        var data: (ValueArray<Double>, ValueArray<Double>) = (ValueArray<Double>(count: windowSize), ValueArray<Double>(count: windowSize))

        for (i, expectedFeature) in sequence.features.enumerate() {
            let offset = sequence.startOffset + i * featureBuilder.stepSize

            var expectedLabel: Label
            if let eventIndex = sequence.events.indexOf({ $0.offset == offset }) {
                let event = sequence.events[eventIndex]
                expectedLabel = Label(notes: event.notes, velocities: event.velocities, onset: sequence.featureOnsetValues[i], polyphony: Float(event.notes.count))
            } else {
                expectedLabel = Label()
                expectedLabel.onset = sequence.featureOnsetValues[i]
                expectedLabel.polyphony = sequence.featurePolyphonyValues[i]
            }
            
            loadExampleData(filePath, offset: offset, data: &data)
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

    func loadExampleData(filePath: String, offset: Int, inout data: (ValueArray<Double>, ValueArray<Double>)) {
        guard let file = AudioFile.open(filePath) else {
            fatalError("File not found '\(filePath)'")
        }

        withPointers(&data.0, &data.1) { p0, p1 in
            readAtFrame(file, frame: offset, data: p0)
            readAtFrame(file, frame: offset + featureBuilder.stepSize, data: p1)
        }
    }

    func readAtFrame(file: AudioFile, frame: Int, data: UnsafeMutablePointer<Double>) {
        if frame >= 0 {
            file.currentFrame = frame
            guard let read = file.readFrames(data, count: featureBuilder.windowSize) else {
                fatalError("Failed to read audio data")
            }
            for i in read..<featureBuilder.windowSize {
                data[i] = 0.0
            }
        } else {
            file.currentFrame = 0
            let fillSize = -frame
            for i in 0..<fillSize {
                data[i] = 0.0
            }

            let readCount = featureBuilder.windowSize - fillSize
            if readCount > 0 {
                guard let read = file.readFrames(data + fillSize, count: readCount) else {
                    fatalError("Failed to read audio data")
                }
                for i in fillSize + read..<featureBuilder.windowSize {
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

        let onsetIndexInWindow = -offset
        let label: Label
        if onsetIndexInWindow >= 0 && onsetIndexInWindow < featureBuilder.windowingFunction.count {
            let note = Note(midiNoteNumber: noteNumber)
            let onset = Float(featureBuilder.windowingFunction[onsetIndexInWindow])
            let velocity = Float(0.75)

            label = Label(notes: [note], velocities: [velocity], onset: onset, polyphony: 1.0)
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
            let margin = (1.0 / 8.0) * Double(featureBuilder.windowSize) / Configuration.samplingFrequency

            let offsetStart = offset - featureBuilder.windowSize / 2
            let timeStart = margin + Double(offsetStart) / Configuration.samplingFrequency
            let beatStart = midFile.beatsForSeconds(timeStart)

            let offsetEnd = offset + featureBuilder.windowSize / 2
            let timeEnd = Double(offsetEnd) / Configuration.samplingFrequency - margin
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
        let event = events[targetEventIndex]
        let notes = event.notes
        return Label(notes: notes, velocities: event.velocities, onset: onsetValueForWindowAt(offset, events: events), polyphony: Float(notes.count))
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
    if lhs.onset != rhs.onset {
        return false
    }
    if lhs.polyphony != rhs.polyphony {
        print(lhs.polyphony, rhs.polyphony)
        return false
    }
    return true
}
