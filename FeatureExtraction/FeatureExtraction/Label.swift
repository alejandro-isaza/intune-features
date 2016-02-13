//  Copyright © 2016 Venture Media. All rights reserved.

import Foundation

/// Label data for a window of audio data
public struct Label {
    /// The onset value is the window-weighted occurrence of onsets in the window
    public var onset: Float

    /// The polyphony value
    public var polyphony: Float

    /// The note value for each note
    public var notes: [Float]

    public init() {
        onset = 0
        polyphony = 0
        notes = [Float](count: Note.noteCount, repeatedValue: 0.0)
    }

    public init(onset: Float, polyphony: Float, notes: [Float]) {
        self.onset = onset
        self.polyphony = polyphony
        self.notes = notes
    }
}
