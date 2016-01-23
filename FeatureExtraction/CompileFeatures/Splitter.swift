//  Copyright © 2016 Venture Media. All rights reserved.

import AudioToolbox
import Peak
import FeatureExtraction

// Methods to split a sequence of MIDI events into chunks
class Splitter {
    let midiFile: MIDIFile
    let events: [MIDINoteEvent]

    var sequences = [[MIDINoteEvent]]()
    var currentSequence = [MIDINoteEvent]()
    var nextSequence = [MIDINoteEvent]()

    var currentSequenceStartBeat = 0.0
    var currentSequenceEndBeat = 0.0
    var currentSequenceStartTime = 0.0
    var currentSequenceEndTime = 0.0

    var currentSequenceCutoffTime = Sequence.maximumSequenceDuration

    init(midiFile: MIDIFile) {
        self.midiFile = midiFile
        self.events = midiFile.noteEvents
    }
    
    func split() -> [[MIDINoteEvent]] {
        for event in events {
            let eventStartBeat = event.timeStamp
            let eventEndBeat = eventStartBeat + Double(event.duration)

            if eventEndBeat <= currentSequenceEndBeat {
                // Event fits in the current sequence
                currentSequence.append(event)
                continue
            }

            let currentSequenceDuration = currentSequenceEndTime - currentSequenceStartTime
            let eventEndTime = midiFile.secondsForBeats(eventEndBeat)

            if currentSequenceDuration < Sequence.minimumSequenceDuration {
                // Event extends the curren sequence
                currentSequence.append(event)
                currentSequenceEndBeat = eventEndBeat
                currentSequenceEndTime = eventEndTime
                continue
            }

            if eventStartBeat >= currentSequenceEndBeat {
                // Event starts a new sequence
                startNewSequence(event)
                continue
            }

            if eventEndTime <= currentSequenceCutoffTime {
                // Event extends the curren sequence
                currentSequence.append(event)
                currentSequenceEndBeat = eventEndBeat
                currentSequenceEndTime = eventEndTime
                continue
            }

            // Event overflows
            let eventStartTime = midiFile.secondsForBeats(eventStartBeat)
            if eventStartTime < currentSequenceCutoffTime {
                currentSequence.append(event)
                nextSequence.append(event)
            } else {
                startNewSequence(event)
            }
        }

        return sequences
    }

    func startNewSequence(event: MIDINoteEvent) {
        assert(!currentSequence.isEmpty)
        sequences.append(currentSequence)
        currentSequence.removeAll()

        currentSequence.appendContentsOf(nextSequence)
        nextSequence.removeAll()
        currentSequence.append(event)

        currentSequenceStartBeat = currentSequence.first!.timeStamp
        currentSequenceStartTime = midiFile.secondsForBeats(currentSequenceStartBeat)

        let lastEvent = currentSequence.last!
        currentSequenceEndBeat = lastEvent.timeStamp + Double(lastEvent.duration)
        currentSequenceEndTime = midiFile.secondsForBeats(currentSequenceEndBeat)

        currentSequenceCutoffTime = currentSequenceStartTime + Sequence.maximumSequenceDuration
    }
}
