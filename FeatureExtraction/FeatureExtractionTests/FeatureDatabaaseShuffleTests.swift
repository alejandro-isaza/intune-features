//  Copyright © 2015 Venture Media. All rights reserved.

import FeatureExtraction
import HDF5Kit
import Upsurge
import XCTest

class FeatureDatabaaseShuffleTests: XCTestCase {
    override func setUp() {
        super.setUp()

        let database = FeatureDatabase(filePath: "test.h5", overwrite: true, chunkSize: Note.noteCount)

        // Create one feature for each note
        for n in Note.representableRange {
            let sequence = Sequence(filePath: "", startOffset: 0)

            let event = Sequence.Event()
            event.offset = 0
            event.notes = [Note(midiNoteNumber: n)]
            event.velocities = [1.0]
            sequence.events.append(event)

            var feature = Feature()
            feature.spectrum = RealArray(count: FeatureBuilder.bandNotes.count)
            feature.spectralFlux = RealArray(count: FeatureBuilder.bandNotes.count)
            feature.peakHeights = RealArray(count: FeatureBuilder.bandNotes.count)
            feature.peakLocations = RealArray(count: FeatureBuilder.bandNotes.count)
            sequence.features.append(feature)
            sequence.featureOnsetValues.append(0)
            sequence.featurePolyphonyValues.append(0)
            
            try! database.appendSequence(sequence)
        }

        try! database.shuffle(chunkSize: 10, passes: 2, progress: nil)
    }

    func testShuffle() {
        let database = FeatureDatabase(filePath: "test.h5", overwrite: false, chunkSize: Note.noteCount)
        let count = database.sequenceCount
        XCTAssertEqual(count, Note.noteCount)

        var shuffledSequences = [Sequence]()
        shuffledSequences.reserveCapacity(count)
        for i in 0..<count {
            try! shuffledSequences.append(database.readSequenceAtIndex(i))
        }

        var movedCount = 0
        for i in 0..<Note.noteCount {
            let note = Note(midiNoteNumber: i + Note.representableRange.start)
            let notes = shuffledSequences[i].events[0].notes
            XCTAssertEqual(notes.count, 1)
            if notes[0] != note {
                movedCount += 1
            }
        }

        XCTAssert(movedCount > 0)
    }

}
