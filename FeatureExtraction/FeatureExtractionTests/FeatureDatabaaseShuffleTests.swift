//  Copyright © 2015 Venture Media. All rights reserved.

import HDF5Kit
import XCTest

class FeatureDatabaaseShuffleTests: XCTestCase {
    var database: FeatureDatabase!

    override func setUp() {
        super.setUp()

        // Create one feature for each note
        var features = [FeatureData]()
        for n in Label.representableRange {
            let note = Note(midiNoteNumber: n)
            let label = Label(note: note, atTime: 0)
            features.append(FeatureData(filePath: "a", fileOffset: 0, label: label))
        }

        // Create a new database with the features
        database = FeatureDatabase(filePath: "test.h5", overwrite: true, chunkSize: features.count)
        database.appendFeatures(features)
    }

    func testShuffle() {
        database.shuffle(chunkSize: 10, passes: 2, progress: nil)
        let shuffledFeatures = database.readFeatures(0, count: Label.representableRange.count)

        var movedCount = 0
        for i in 0..<Label.representableRange.count {
            let note = Note(midiNoteNumber: i + Label.representableRange.start)
            if shuffledFeatures[i].label.notes[0] != note {
                movedCount += 1
            }
        }

        XCTAssert(movedCount > 0)
    }

}
