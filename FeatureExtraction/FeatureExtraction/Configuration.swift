//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public final class Configuration {
    /// Input audio data sampling frequency
    public static let samplingFrequency = 44100.0

    /// Analysis window sizes
    public static let windowSizes = [2*1024, 4*1024, 8*1024, 16*1024]

    /// Step size as the inverse fraction of the window size
    public static let stepFraction = 2

    /// The range of notes to consider for labeling
    public static let notes = 21...108

    /// The range of notes to include in the spectrums
    public static let bandNotes = 21...120

    /// The note resolution for the spectrums
    public static let bandSize = 1.0

    /// The peak height cutoff as a multiplier of the RMS
    public static let peakHeightCutoffMultiplier = 0.05

    /// The minimum distance between peaks in notes
    public static let peakMinimumNoteDistance = 0.5

    /// Calculate the number of windows that fit inside the given number of samples
    public static func windowCountInSamples(samples: Int, windowSize: Int) -> Int {
        if samples < windowSize {
            return 0
        }
        let stepSize = windowSize / stepFraction
        return 1 + (samples - windowSize) / stepSize
    }

    /// Calculate the number of samples in the given number of contiguous windows
    public static func sampleCountInWindows(windowCount: Int, windowSize: Int) -> Int {
        if windowCount < 1 {
            return 0
        }
        let stepSize = windowSize / stepFraction
        return (windowCount - 1) * stepSize + windowSize
    }

    public static func baseFrequencyForWindowSize(windowSize: Int) -> Double {
        return Configuration.samplingFrequency / Double(windowSize)
    }
}
