//  Copyright © 2016 Venture Media. All rights reserved.

import Peak
import AudioToolbox


class MIDIMixer {
    static let minChunkSize = 5
    static let maxChunkSize = 18
    static let maxDelay = 0.3
    static let maxMistake = 4

    static let duplicationProbability = 0.2
    static let mistakeProbability = 0.25

    static let mistakeBuffer = 0.05


    var inputFile: MIDIFile?
    var inputEvents: [MIDINoteEvent]
    var chunks = [Chunk]()

    var referenceIndices: [Int] {
        return chunks.flatMap({ $0.chords.map({ $0.index }) })
    }


    init(inputFile: MIDIFile) {
        self.inputFile = inputFile
        self.inputEvents = inputFile.noteEvents
    }

    init(inputEvents: [MIDINoteEvent]) {
        self.inputEvents = inputEvents
    }

    func mix() {
        chunks = splitChunks()
        duplicateChunks()
        addMistakes()
        addDelays()
    }

    func splitChunks() -> [Chunk] {
        var chunkedEvents = Chunk(events: inputEvents)
        var splitChunks = [Chunk]()

        var chunkSize = min(random(min: MIDIMixer.minChunkSize, max: MIDIMixer.maxChunkSize), inputEvents.count)
        var chunk = Chunk()
        var chordCount = 0
        var noteCount = 0
        chunkedEvents.applyToChords() { chord in
            if chordCount < chunkSize {
                chunk.chords.append(chord)
                chordCount += 1
                noteCount += chord.events.count
            } else {
                splitChunks.append(chunk)
                chunkSize = min(random(min: MIDIMixer.minChunkSize, max: MIDIMixer.maxChunkSize), self.inputEvents.count - noteCount)
                chunk = [chord]
                chordCount = 1
                noteCount = chord.events.count
            }
        }
        if chordCount > 0 {
            splitChunks.append(chunk)
        }
        return splitChunks
    }

    func duplicateChunks() {
        let iterableChunks = chunks
        var offset = 0
        for (i, chunk) in iterableChunks.enumerate() {
            if random(probability: MIDIMixer.duplicationProbability) {
                chunks.insert(chunks[i+offset], atIndex: i+offset)

                offset += 1
                shiftChunks(&chunks[i+offset..<chunks.count], offset: chunk.duration)
            }
        }
    }

    func addDelays() {
        var offset = 0.0
        applyToChords(&chunks){ chord in
            let delay = random(min: -MIDIMixer.maxDelay, max: MIDIMixer.maxDelay)
            assert((-MIDIMixer.maxDelay...MIDIMixer.maxDelay).contains(delay))
            for i in 0..<chord.events.count {
                chord.events[i].timeStamp = max(chord.events[i].timeStamp + offset + delay, 0)
            }
            offset += delay
        }
    }

    func addMistakes() {
        for i in 0..<chunks.count-1 {
            if random(probability: MIDIMixer.mistakeProbability) {
                var nextChord = chunks[i+1].chords[0]
                nextChord.index = chunks[i].chords.last!.index
                for j in 0..<nextChord.events.count {
                    let mistake = random(min: 1, max: MIDIMixer.maxMistake+1)
                    let sign = random(probability: 0.5) ? 1 : -1
                    nextChord.events[j].note += UInt8(sign * mistake)
                }

                chunks[i].chords.append(nextChord)
                shiftChunks(&chunks[i+1..<chunks.count], offset: Double(nextChord.duration! + MIDIMixer.mistakeBuffer))
            }
        }
    }

    func constructSequence() -> MusicSequence {
        var sequence: MusicSequence = nil
        guard NewMusicSequence(&sequence) == noErr else {
            fatalError("Failed to create MusicSequence")
        }
        constructTrack(&sequence)
        setTempo(&sequence)
        return sequence
    }

    func constructTrack(inout sequence: MusicSequence) {
        var track: MusicTrack = nil

        guard MusicSequenceNewTrack(sequence, &track) == noErr else {
            fatalError("Failed to add track to sequence.")
        }

        for chunk in chunks {
            for chord in chunk.chords {
                for event in chord.events {
                    var message = MIDINoteMessage(channel: event.channel, note: event.note, velocity: event.velocity, releaseVelocity: 0, duration: event.duration)
                    MusicTrackNewMIDINoteEvent(track, event.timeStamp, &message)
                }
            }
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

        for event in inputFile!.tempoEvents {
            guard MusicTrackNewExtendedTempoEvent(tempoTrack, event.timeStamp, event.bpm) == noErr else {
                fatalError("Could not create tempo event")
            }
        }
    }
}