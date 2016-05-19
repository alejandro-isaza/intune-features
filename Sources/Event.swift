// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Peak

public struct Event {
    /// The note
    public var note = Note(midiNoteNumber: 60)

    /// The start of the event in samples
    public var start = 0

    /// The duration of the event in samples
    public var duration = 0

    /// The note's MIDI velocity between 0 and 1
    public var velocity = Float(0)

    public init() {
    }

    public init(note: Note, start: Int, duration: Int, velocity: Float) {
        self.note = note
        self.start = start
        self.duration = duration
        self.velocity = velocity
    }

    public init(midiNoteEvent: MIDINoteEvent, inFile file: MIDIFile, samplingFrequency: Double) {
        note = Note(midiNoteNumber: Int(midiNoteEvent.note))
        start = Int(file.secondsForBeats(midiNoteEvent.timeStamp) * samplingFrequency)
        let end = Int(file.secondsForBeats(midiNoteEvent.timeStamp + Double(midiNoteEvent.duration)) * samplingFrequency)
        duration = end - start
        velocity = Float(midiNoteEvent.velocity) / 127.0
    }
}
