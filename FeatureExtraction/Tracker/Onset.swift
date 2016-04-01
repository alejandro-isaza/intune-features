//  Copyright © 2016 Venture Media. All rights reserved.

import AudioToolbox
import FeatureExtraction
import Peak

public struct Onset {
    public var notes: [Note]

    /// The start time in beats
    public var start: Double

    /// The time of this event in seconds when played at the song's tempo
    public var wallTime: Double
}

public func onsetsFromMIDI(midi: MIDIFile) -> [Onset] {
    var eventsByTime = [MusicTimeStamp: [MIDINoteEvent]]()
    for event in midi.noteEvents {
        var array = eventsByTime[event.timeStamp] ?? [MIDINoteEvent]()
        array.append(event)
        eventsByTime.updateValue(array, forKey: event.timeStamp)
    }

    var onsets = [Onset]()
    for time in eventsByTime.keys.sort() {
        let events = eventsByTime[time]!
        let notes = events.map({ Note(midiNoteNumber: Int($0.note)) })
        let wallTime = midi.secondsForBeats(time)
        let onset = Onset(notes: notes, start: time, wallTime: wallTime)
        onsets.append(onset)
    }

    return onsets
}
