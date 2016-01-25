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

    var currentSequenceStartBeat = 0.0
    var currentSequenceEndBeat = 0.0
    var currentSequenceStartTime = 0.0
    var currentSequenceEndTime = 0.0
    var currentSequenceCutoffTime = Sequence.maximumSequenceDuration

    var index = 0
    var restartIndex: Int?

    init(midiFile: MIDIFile) {
        self.midiFile = midiFile
        self.events = midiFile.noteEvents
    }

    /// Split a MIDI file into sequences of at least `Sequence.minimumSequenceDuration` and trying not to exceed `Sequence.maximumSequenceDuration`. This method should only be called once on a given instance of this class.
    func split() -> [[MIDINoteEvent]] {
        while index < events.count {
            let event = events[index]
            index += 1

            let eventStartBeat = event.timeStamp
            let eventEndBeat = eventStartBeat + Double(event.duration)

            if eventEndBeat <= currentSequenceEndBeat {
                // Event fits in the current sequence
                currentSequence.append(event)
                continue
            }

            let currentSequenceDuration = currentSequenceEndTime - currentSequenceStartTime
            let eventStartTime = midiFile.secondsForBeats(eventStartBeat)
            let eventEndTime = midiFile.secondsForBeats(eventEndBeat)

            if currentSequenceDuration < Sequence.minimumSequenceDuration && eventStartTime - currentSequenceStartTime < Sequence.maximumSequenceDuration {
                // Event extends the curren sequence
                currentSequence.append(event)
                currentSequenceEndBeat = eventEndBeat
                currentSequenceEndTime = eventEndTime
                continue
            }

            if eventStartBeat >= currentSequenceEndBeat {
                // Event starts a new sequence
                index = startNewSequence(event)
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
            if eventStartTime < currentSequenceCutoffTime {
                currentSequence.append(event)
                if restartIndex == nil {
                    restartIndex = index - 1
                }
            } else {
                index = startNewSequence(event)
            }
        }

        return sequences
    }

    func startNewSequence(event: MIDINoteEvent) -> Int {
        closeCurrentSequence()

        currentSequence.append(event)

        currentSequenceStartBeat = event.timeStamp
        currentSequenceStartTime = midiFile.secondsForBeats(currentSequenceStartBeat)

        currentSequenceEndBeat = event.timeStamp + Double(event.duration)
        currentSequenceEndTime = midiFile.secondsForBeats(currentSequenceEndBeat)

        currentSequenceCutoffTime = currentSequenceStartTime + Sequence.maximumSequenceDuration

        if let newIndex = restartIndex {
            restartIndex = nil
            return newIndex
        }

        return index
    }

    func closeCurrentSequence() {
        assert(!currentSequence.isEmpty)
        assert(currentSequenceEndTime - currentSequenceStartTime >= Sequence.minimumSequenceDuration)

        sequences.append(currentSequence)
        currentSequence.removeAll()
    }
}
