//  Copyright © 2016 Venture Media. All rights reserved.

import Peak
import AudioToolbox


struct Chunk: ArrayLiteralConvertible {
    var chords = [Chord]()

    var duration: Double {
        var duration = (chords.last?.timestamp ?? 0.0) - (chords.first?.timestamp ?? 0.0)
        duration += Double(chords.last?.duration ?? 0.0)
        return duration
    }

    init(arrayLiteral chords: Chord...) {
        self.chords = chords
    }

    init(events: [MIDINoteEvent]) {
        var indexDictionary = [MusicTimeStamp:Int]()

        var i = 0
        for event in events {
            if let index = indexDictionary[event.timeStamp] {
                chords[index].events.append(event)
            } else {
                indexDictionary[event.timeStamp] = chords.count
                chords.append(Chord(index: i, event: event))
                i += 1
            }
        }
    }

    mutating func applyToChords(action: (inout Chord) -> Void) {
        for i in 0..<chords.count {
            action(&chords[i])
        }
    }
}

struct Chord {
    var events = [MIDINoteEvent]()
    var index: Int

    var timestamp: Double? {
        return events.first?.timeStamp
    }

    var duration: Double? {
        var maxDuration = 0.0
        for event in events {
            maxDuration = max(maxDuration, Double(event.duration))
        }
        return maxDuration
    }

    init(index: Int, events: MIDINoteEvent...) {
        self.events = events
        self.index = index
    }

    init(index: Int, event: MIDINoteEvent) {
        self.events = [event]
        self.index = index
    }
}

func shiftChunks(inout chunks: ArraySlice<Chunk>, offset: Double) {
    for i in chunks.startIndex..<chunks.endIndex {
        for j in 0..<chunks[i].chords.count {
            for k in 0..<chunks[i].chords[j].events.count {
                chunks[i].chords[j].events[k].timeStamp += Float64(offset)
            }
        }
    }
}

func applyToChords(inout chunks: [Chunk], action: (inout Chord) -> Void) {
    for i in 0..<chunks.count {
        chunks[i].applyToChords(action)
    }
}
