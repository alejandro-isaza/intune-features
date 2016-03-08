//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public struct Configuration {
    /// Input audio data sampling frequency
    public var samplingFrequency = 44100.0

    /// Window size in audio samples
    public var windowSize = 8192

    /// Window step size in audio samples
    public var stepSize = 1024

    /// The range of notes to consider for labeling
    public var representableNoteRange = 21...108

    /// The range of notes to include in the spectrum
    public var spectrumNoteRange = 21...120

    /// The resolution for the spectrum in notes per band
    public var spectrumResolution = 1.0

    /// The frequency resolution for the spectrum
    public var baseFrequency: Double {
        return samplingFrequency / Double(windowSize)
    }

    /// The minimum distance between peaks in notes
    public var minimumPeakDistance = 0.5

    /// The peak height cutoff as a multiplier of the RMS
    public var peakHeightCutoffMultiplier = 0.05

    /// The number of windows to use for the RMS average
    public var rmsMovingAverageSize = 20

    public init() {
    }

    /// Calculate the number of windows that fit inside the given number of samples
    public func windowCountInSamples(samples: Int) -> Int {
        if samples < windowSize {
            return 0
        }
        return 1 + (samples - windowSize) / stepSize
    }

    /// Calculate the number of samples in the given number of contiguous windows
    public func sampleCountInWindows(windowCount: Int) -> Int {
        if windowCount < 1 {
            return 0
        }
        return (windowCount - 1) * stepSize + windowSize
    }


    // MARK: Notes

    public func vectorFromNotes(notes: [Note]) -> [Float] {
        var vector = [Float](count: representableNoteRange.count, repeatedValue: 0.0)
        for note in notes {
            let index = note.midiNoteNumber - representableNoteRange.startIndex
            vector[index] = 1.0
        }
        return vector
    }

    public func notesFromVector<C: CollectionType where C.Generator.Element == Float, C.Index == Int>(vector: C) -> [Note] {
        precondition(vector.count == representableNoteRange.count)
        var notes = [Note]()
        for (index, value) in vector.enumerate() {
            if value < 0.5 {
                continue
            }
            let note = Note(midiNoteNumber: index + representableNoteRange.startIndex)
            notes.append(note)
        }
        return notes
    }

    
    // MARK: Bands

    public var bandCount: Int {
        return spectrumNoteRange.count * Int(spectrumResolution)
    }

    public func bandForNote(note: Double) -> Int {
        return Int(round((note - Double(representableNoteRange.startIndex)) * spectrumResolution))
    }

    public func noteForBand(band: Int) -> Double {
        return Double(representableNoteRange.startIndex) + Double(band) / spectrumResolution
    }


    // MARK: Description

    public var description: String {
        var string = ""
        string += "samplingFrequency = \(samplingFrequency)\n"
        string += "windowSize = \(windowSize)\n"
        string += "stepSize = \(stepSize)\n"
        string += "representableNoteRange = \(representableNoteRange)\n"
        string += "spectrumNoteRange = \(spectrumNoteRange)\n"
        string += "spectrumResolution = \(spectrumResolution)\n"
        string += "minimumPeakDistance = \(minimumPeakDistance)\n"
        string += "peakHeightCutoffMultiplier = \(peakHeightCutoffMultiplier)\n"
        string += "rmsMovingAverageSize = \(rmsMovingAverageSize)\n"
        return string
    }

    public func serializeToJSON() -> String {
        var string = "{\n"

        string += "  \"samplingFrequency\": \(samplingFrequency),\n"
        string += "  \"windowSize\": \(windowSize),\n"
        string += "  \"stepSize\": \(stepSize),\n"
        string += "  \"representableNoteRange\": \"\(representableNoteRange)\",\n"
        string += "  \"spectrumNoteRange\": \"\(spectrumNoteRange)\",\n"
        string += "  \"spectrumResolution\": \(spectrumResolution),\n"
        string += "  \"minimumPeakDistance\": \(minimumPeakDistance),\n"
        string += "  \"peakHeightCutoffMultiplier\": \(peakHeightCutoffMultiplier),\n"
        string += "  \"rmsMovingAverageSize\": \(rmsMovingAverageSize),\n"

        string += "  \"features\": ["
        for feature in Table.features {
            string += "\"\(feature.rawValue)\", "
        }
        if string.hasSuffix(", ") {
            string.removeAtIndex(string.endIndex.advancedBy(-1))
            string.removeAtIndex(string.endIndex.advancedBy(-1))
        }
        string += "]\n"

        string += "}"
        return string
    }
}
