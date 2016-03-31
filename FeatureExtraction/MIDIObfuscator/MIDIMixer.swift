//  Copyright © 2016 Venture Media. All rights reserved.

import Peak
import AudioToolbox


class MIDIMixer {
    let minChunkSize = 3
    let maxChunkSize = 20

    let duplicationProbability = 0.2


    var inputFile: MIDIFile

    init(inputFile: MIDIFile) {
        self.inputFile = inputFile
    }

    func mix() -> MusicSequence {
        var chunks = splitChunks(inputFile.noteEvents)
        duplicateChunks(&chunks)
        var sequence = sequenceFromChunk(chunks.flatMap({ $0 }))
        setTempo(&sequence)
        return sequence
    }

    func splitChunks(inputEvents: [MIDINoteEvent]) -> [Chunk] {
        var chunkedEvents = [Chunk]()
        var i = 0
        while i < inputEvents.count {
            var chunkSize = min(random(min: minChunkSize, max: maxChunkSize), inputEvents.count - i)
            while chunkSize != inputEvents.count - i && inputEvents[i+chunkSize-1].timeStamp == inputEvents[i+chunkSize].timeStamp {
                chunkSize += 1
            }

            let chunk = Chunk(inputEvents[i..<i+chunkSize])
            chunkedEvents.append(chunk)
            i += chunkSize
        }
        return chunkedEvents
    }

    func duplicateChunks(inout chunks: [Chunk]) {
        let iterableChunks = chunks
        var offset = 0
        for (i, chunk) in iterableChunks.enumerate() {
            if random(probability: duplicationProbability) {
                chunks.insert(chunk, atIndex: i+offset)
                offset += 1
                shiftChunks(&chunks[i+offset..<chunks.count], offset: duration(chunk))
            }
        }
    }

    func sequenceFromChunk(chunk: Chunk) -> MusicSequence {
        var sequence: MusicSequence = nil
        guard NewMusicSequence(&sequence) == noErr else {
            fatalError("Failed to create MusicSequence")
        }
        trackFromChunk(&sequence, chunk: chunk)
        return sequence
    }

    func trackFromChunk(inout sequence: MusicSequence, chunk: Chunk) {
        var track: MusicTrack = nil

        guard MusicSequenceNewTrack(sequence, &track) == noErr else {
            fatalError("Failed to add track to sequence.")
        }

        for event in chunk {
            var message = MIDINoteMessage(channel: event.channel, note: event.note, velocity: event.velocity, releaseVelocity: 0, duration: event.duration)
            MusicTrackNewMIDINoteEvent(track, event.timeStamp, &message)
        }

    }

    func setTempo(inout sequence: MusicSequence) {
        var tempoTrack: MusicTrack = nil
        guard MusicSequenceGetTempoTrack(sequence, &tempoTrack) == noErr else {
            fatalError("Could not read tempo track")
        }

        var trackLength = MusicTimeStamp()
        guard MusicTrackGetProperty(tempoTrack, kSequenceTrackProperty_TrackLength, &trackLength, nil) == noErr else {
            fatalError("Could not read track length")
        }

        if trackLength != 0 {
            guard MusicTrackClear(tempoTrack, 0, trackLength) == noErr else {
                fatalError("Could not clear tempo track")
            }
        }

        for event in inputFile.tempoEvents {
            guard MusicTrackNewExtendedTempoEvent(tempoTrack, event.timeStamp, event.bpm) == noErr else {
                fatalError("Could not create tempo event")
            }
        }
    }
}