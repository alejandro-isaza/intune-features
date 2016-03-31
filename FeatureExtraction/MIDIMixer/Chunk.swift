//  Copyright © 2016 Venture Media. All rights reserved.

import Peak
import AudioToolbox


typealias Chunk = [Chord]
typealias Chord = [MIDINoteEvent]

func shiftChunks(inout chunks: ArraySlice<Chunk>, offset: Double) {
    for i in chunks.startIndex..<chunks.endIndex {
        for j in 0..<chunks[i].count {
            for k in 0..<chunks[i][j].count {
                chunks[i][j][k].timeStamp += Float64(offset)
            }
        }
    }
}

func duration(chunk: Chunk) -> Double {
    var duration = (chunk.last?.last?.timeStamp ?? 0.0) - (chunk.first?.first?.timeStamp ?? 0.0)
    duration += Double(chunk.last?.last?.duration ?? 0.0)
    return duration
}

func chunkFromEvents(events: [MIDINoteEvent]) -> Chunk {
    var chunk = Chunk()
    var indexDictionary = [MusicTimeStamp:Int]()

    for event in events {
        if let index = indexDictionary[event.timeStamp] {
            chunk[index].append(event)
        } else {
            indexDictionary[event.timeStamp] = chunk.count
            chunk.append([event])
        }
    }

    return chunk
}

func applyToChords(inout chunk: Chunk, action: (inout Chord) -> Void) {
    for i in 0..<chunk.count {
        action(&chunk[i])
    }
}

func applyToChords(inout chunks: [Chunk], action: (inout Chord) -> Void) {
    for i in 0..<chunks.count {
        for j in 0..<chunks[i].count {
            action(&chunks[i][j])
        }
    }
}
