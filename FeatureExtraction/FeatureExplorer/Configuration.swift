//  Copyright © 2015 Venture Media. All rights reserved.

import FeatureExtraction

struct Configuration {
    // Basic parameters
    static let sampleRate  = 44100
    static let sampleCount = 8*1024
    static let sampleStep  = sampleCount / 2

    // Notes and bands parameters
    static let notes = 36...96
    static let bandNotes = 24...120
    static let bandSize = 1.0

    // Peaks parameters
    static let peakHeightCutoffMultiplier = 0.05
    static let peakMinimumNoteDistance = 0.5
}
