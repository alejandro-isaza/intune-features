//  Copyright © 2016 Venture Media. All rights reserved.

import XCTest
import Peak

class MIDIMixerTests: XCTestCase {
    let midiEventCount = 10

    var midiMixer: MIDIMixer? = nil

    override func setUp() {
        super.setUp()

        var inputEvents = [MIDINoteEvent]()
        let event = MIDINoteEvent(timeStamp: Float64(50), duration: Float32(0.5), channel: 0, note: 0, velocity: UInt8(0))
        inputEvents.append(event)
        for i in 1..<midiEventCount {
            let sign = random(probability: 0.5) ? 1 : -1
            let offset = sign * random(min: MIDIMixer.maxMistake+1, max: MIDIMixer.maxMistake+2)
            var note = Int(inputEvents[i-1].note) + offset
            if note < 24 {
                note = random(min: Int(inputEvents[i-1].note) + MIDIMixer.maxMistake + 1, max: 108)
            } else if note > 108 {
                note = random(min: 24, max: Int(inputEvents[i-1].note) - MIDIMixer.maxMistake - 1)
            }
            let event = MIDINoteEvent(timeStamp: Float64(i), duration: Float32(0.5), channel: 0, note: UInt8(note), velocity: UInt8(0))
            inputEvents.append(event)
        }

        midiMixer = MIDIMixer(inputEvents: inputEvents)
    }
    
    func testReferenceIndices() {
        guard let midiMixer = midiMixer else {
            fatalError()
        }

        midiMixer.duplicateChunks()
        midiMixer.addMistakes()
        midiMixer.addDelays()
        let inputChunk = Chunk(events: midiMixer.inputEvents)
        let mixedChunk = midiMixer.chunks.reduce(Chunk(), combine: { (chunk, otherChunk) in
            var temp = chunk
            temp.chords.appendContentsOf(otherChunk.chords)
            return temp
        })
        for (mixedIndex, referenceIndex) in midiMixer.referenceIndices.enumerate() {
            if mixedIndex == 0 || midiMixer.referenceIndices[mixedIndex] != midiMixer.referenceIndices[mixedIndex-1] {
                XCTAssert(equalNote(inputChunk.chords[referenceIndex], mixedChunk.chords[mixedIndex]))
            }
        }
    }

    func testAddMistakes() {
        guard let midiMixer = midiMixer else {
            fatalError()
        }
        midiMixer.chunks = midiMixer.splitChunks()
        let chunksNoMistakes = midiMixer.chunks
        midiMixer.addMistakes()
        let chunksMistakes = midiMixer.chunks
        XCTAssert(chunksMistakes.count == chunksNoMistakes.count)

        for i in 0..<chunksMistakes.count {
            let noMistakeChunk = chunksNoMistakes[i]
            let mistakeChunk = chunksMistakes[i]

            if noMistakeChunk.chords.count != mistakeChunk.chords.count {
                XCTAssert(!equalNote(noMistakeChunk.chords.last!, mistakeChunk.chords.last!))
                XCTAssert(equalNote(mistakeChunk.chords[noMistakeChunk.chords.count-1], noMistakeChunk.chords.last!))
            }
        }
    }

    func testAddDelays() {
        guard let midiMixer = midiMixer else {
            fatalError()
        }
        midiMixer.chunks = midiMixer.splitChunks()
        let chunksNoDelays = midiMixer.chunks
        midiMixer.addDelays()
        let chunksDelays = midiMixer.chunks
        XCTAssert(chunksDelays.count == chunksNoDelays.count)

        var offset = 0.0
        var shiftedCount = 0
        for i in 0..<chunksDelays.count {
            let noDelayChunk = chunksNoDelays[i]
            let delayChunk = chunksDelays[i]

            for j in 0..<delayChunk.chords.count {
                let delay = (delayChunk.chords[j].timestamp! - offset) - noDelayChunk.chords[j].timestamp!
                if delay != 0 {
                    offset += delay
                    shiftedCount += 1
                }
                XCTAssertLessThanOrEqual(abs(delay), MIDIMixer.maxDelay)
            }
        }
        XCTAssertNotEqual(0, shiftedCount)
    }

    func testAddDuplication() {
        guard let midiMixer = midiMixer else {
            fatalError()
        }

        midiMixer.chunks = midiMixer.splitChunks()
        midiMixer.duplicateChunks()

        let inputChunk = Chunk(events: midiMixer.inputEvents)
        let mixedChunk = midiMixer.chunks.reduce(Chunk(), combine: { (chunk, otherChunk) in
            var temp = chunk
            temp.chords.appendContentsOf(otherChunk.chords)
            return temp
        })
        for (mixedIndex, referenceIndex) in midiMixer.referenceIndices.enumerate() {
            if mixedIndex == 0 || midiMixer.referenceIndices[mixedIndex] != midiMixer.referenceIndices[mixedIndex-1] {
                XCTAssert(equalNote(inputChunk.chords[referenceIndex], mixedChunk.chords[mixedIndex]))
            }
        }
    }
}

func equalNote(lhs: Chord, _ rhs: Chord) -> Bool {
    if lhs.events.count != rhs.events.count {
        return false
    }
    var rhsTemp = rhs
    for lhsEvent in lhs.events {
        if let index = rhsTemp.events.indexOf({ $0.note == lhsEvent.note }) {
            rhsTemp.events.removeAtIndex(index)
        } else {
            return false
        }
    }
    return rhsTemp.events.count == 0
}

