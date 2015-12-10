//  Copyright © 2015 Venture Media. All rights reserved.

import FeatureExtraction
import HDF5Kit
import Upsurge
import XCTest

class FeatureDatabaaseShuffleTests: XCTestCase {
    override func setUp() {
        super.setUp()

        // Create one feature for each note
        var features = [FeatureData]()
        for n in Label.representableRange {
            let note = Note(midiNoteNumber: n)
            let label = Label(note: note, atTime: 0)
            XCTAssertEqual(label.notes.count, 1)
            let feature = FeatureData(filePath: "a", fileOffset: 0, label: label)

            for name in FeatureDatabase.featureNames {
                feature.features[name] = RealArray(count: FeatureBuilder.bandNotes.count)
            }
            features.append(feature)
        }

        let database = FeatureDatabase(filePath: "test.h5", overwrite: true, chunkSize: features.count)
        database.appendFeatures(features)
        database.shuffle(chunkSize: 10, passes: 2, progress: nil)
    }

    func testShuffle() {
        let database = FeatureDatabase(filePath: "test.h5", overwrite: false, chunkSize: Label.representableRange.count)
        let shuffledFeatures = database.readFeatures(0, count: Label.representableRange.count)

        var movedCount = 0
        for i in 0..<Label.representableRange.count {
            let note = Note(midiNoteNumber: i + Label.representableRange.start)
            let label = shuffledFeatures[i].label
            XCTAssertEqual(label.notes.count, 1)
            if label.notes[0] != note {
                movedCount += 1
            }
        }

        XCTAssert(movedCount > 0)
    }

}
