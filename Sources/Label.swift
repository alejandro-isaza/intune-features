// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation

/// Label data for a window of audio data
public struct Label {
    /// The onset value is the window-weighted occurrence of onsets in the window
    public var onset: Float

    /// The polyphony value
    public var polyphony: Float

    /// The note value for each note
    public var notes: [Float]

    public init(noteCount: Int) {
        onset = 0
        polyphony = 0
        notes = [Float](repeating: 0, count: noteCount)
    }

    public init(onset: Float, polyphony: Float, notes: [Float]) {
        self.onset = onset
        self.polyphony = polyphony
        self.notes = notes
    }
}
