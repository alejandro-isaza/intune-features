//  Copyright © 2016 Venture Media. All rights reserved.

import Peak


typealias Chunk = [MIDINoteEvent]

func shiftChunks(inout chunks: ArraySlice<Chunk>, offset: Double) {
    for i in chunks.startIndex..<chunks.endIndex {
        for j in 0..<chunks[i].count {
            chunks[i][j].timeStamp += Float64(offset)
        }
    }
}

func duration(chunk: Chunk) -> Double {
    var duration = (chunk.last?.timeStamp ?? 0.0) - (chunk.first?.timeStamp ?? 0.0)
    duration += Double(chunk.last?.duration ?? 0.0)
    return duration
}
