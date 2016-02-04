//  Copyright © 2016 Venture Media. All rights reserved.

import FeatureExtraction
import HDF5Kit
import Upsurge
import XCTest

func randomInInterval(interval: ClosedInterval<Float>) -> Float {
    let r = Float(randomInRange(0..<Int.max)) / Float(Int.max)
    return interval.start + (interval.end - interval.start) * r
}

class FeatureDatabaseTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    func testWriteRead() {
        let sequence = Sequence(filePath: "file", startOffset: 4236)

        let event = Sequence.Event()
        event.offset = 8234
        event.notes = [Note(midiNoteNumber: 43)]
        event.velocities = [0.75]
        sequence.events.append(event)

        let feature1 = Feature()
        for i in 0..<FeatureBuilder.bandNotes.count {
            feature1.spectrum[i] = randomInInterval(ClosedInterval(0, 1))
            feature1.spectralFlux[i] = randomInInterval(ClosedInterval(0, 1))
            feature1.peakHeights[i] = randomInInterval(ClosedInterval(0, 1))
            feature1.peakLocations[i] = randomInInterval(ClosedInterval(0, 1))
        }
        sequence.features.append(feature1)
        sequence.featureOnsetValues.append(0.23)
        sequence.featurePolyphonyValues.append(2)

        let feature2 = Feature()
        for i in 0..<FeatureBuilder.bandNotes.count {
            feature2.spectrum[i] = randomInInterval(ClosedInterval(0, 1))
            feature2.spectralFlux[i] = randomInInterval(ClosedInterval(0, 1))
            feature2.peakHeights[i] = randomInInterval(ClosedInterval(0, 1))
            feature2.peakLocations[i] = randomInInterval(ClosedInterval(0, 1))
        }
        sequence.features.append(feature2)
        sequence.featureOnsetValues.append(0.65)
        sequence.featurePolyphonyValues.append(1)

        write(sequence)

        let database = FeatureDatabase(filePath: "test.h5", overwrite: false, chunkSize: 1)
        let readSequence = try! database.readSequenceAtIndex(0)

        XCTAssertEqual(readSequence.filePath, sequence.filePath)
        XCTAssertEqual(readSequence.startOffset, sequence.startOffset)

        XCTAssertEqual(readSequence.events.count, 1)
        let readEvent = readSequence.events.first!
        XCTAssertEqual(readEvent.offset, event.offset)
        XCTAssertEqual(readEvent.notes, event.notes)
        XCTAssertEqual(readEvent.velocities, event.velocities)

        XCTAssertEqual(readSequence.features.count, 2)
        let readFeature1 = readSequence.features[0]
        XCTAssertEqual(readFeature1.spectrum, feature1.spectrum)
        XCTAssertEqual(readFeature1.spectralFlux, feature1.spectralFlux)
        XCTAssertEqual(readFeature1.peakHeights, feature1.peakHeights)
        XCTAssertEqual(readFeature1.peakLocations, feature1.peakLocations)

        let readFeature2 = readSequence.features[1]
        XCTAssertEqual(readFeature2.spectrum, feature2.spectrum)
        XCTAssertEqual(readFeature2.spectralFlux, feature2.spectralFlux)
        XCTAssertEqual(readFeature2.peakHeights, feature2.peakHeights)
        XCTAssertEqual(readFeature2.peakLocations, feature2.peakLocations)

        XCTAssertEqual(readSequence.featureOnsetValues, sequence.featureOnsetValues)
        XCTAssertEqual(readSequence.featurePolyphonyValues, sequence.featurePolyphonyValues)
    }

    func write(sequence: Sequence) {
        let writeDB = FeatureDatabase(filePath: "test.h5", overwrite: true, chunkSize: 1)
        try! writeDB.appendSequence(sequence)
    }

}
