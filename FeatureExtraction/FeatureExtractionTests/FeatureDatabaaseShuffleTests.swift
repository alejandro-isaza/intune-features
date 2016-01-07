//  Copyright © 2015 Venture Media. All rights reserved.

import FeatureExtraction
import HDF5Kit
import Upsurge
import Peak
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
        try! database.appendFeatures(features)
        try! database.shuffle(chunkSize: 10, passes: 2, progress: nil)

        // Create features from audio file
        let builder = FeatureBuilder()
        let fileName = "37.m4a"
        var noShuffleFeatures = [FeatureData]()
        var shuffleFeatures = [FeatureData]()
        let bundle = NSBundle(forClass: self.dynamicType)
        let path = bundle.pathForResource("37", ofType: "m4a")!
        let audioFile = AudioFile.open(path)!
        for i in 0..<5 {
            let offset = i * FeatureBuilder.sampleCount
            let example = Example(filePath: fileName, frameOffset: offset, label: Label(note: Note(midiNoteNumber: 37), atTime: 0), data: (RealArray(count: FeatureBuilder.sampleCount), RealArray(count: FeatureBuilder.sampleCount)))
            audioFile.readFrames(example.data.0.mutablePointer, count: FeatureBuilder.sampleCount)
            audioFile.currentFrame = offset + FeatureBuilder.sampleStep
            audioFile.readFrames(example.data.1.mutablePointer, count: FeatureBuilder.sampleCount)
            audioFile.currentFrame = offset + FeatureBuilder.sampleCount
            
            let feature = FeatureData(filePath: example.filePath, fileOffset: example.frameOffset, label: example.label, features: builder.generateFeatures(example))
            noShuffleFeatures.append(feature)
            shuffleFeatures.append(feature)
        }
        
        let shuffledDatabase = FeatureDatabase(filePath: "test-audiofile-shuffled.h5", overwrite: true, chunkSize: shuffleFeatures.count)
        try! shuffledDatabase.appendFeatures(shuffleFeatures)
        try! shuffledDatabase.shuffle(chunkSize: 10, passes: 2, progress: nil)

        let noShuffleDatabase = FeatureDatabase(filePath: "test-audiofile.h5", overwrite: true, chunkSize: noShuffleFeatures.count)
        try! noShuffleDatabase.appendFeatures(noShuffleFeatures)
        try! noShuffleDatabase.shuffle(chunkSize: 10, passes: 2, progress: nil)

    }

    func testShuffle() {
        let database = FeatureDatabase(filePath: "test.h5", overwrite: false, chunkSize: Label.noteCount)
        let shuffledFeatures = database.readFeatures(0, count: Label.noteCount)

        var movedCount = 0
        for i in 0..<Label.noteCount {
            let note = Note(midiNoteNumber: i + Label.representableRange.start)
            let label = shuffledFeatures[i].label
            XCTAssertEqual(label.notes.count, 1)
            if label.notes[0] != note {
                movedCount += 1
            }
        }

        XCTAssert(movedCount > 0)
    }
    
    func testShuffleDataPreservation() {
        let shuffledDatabase = FeatureDatabase(filePath: "test-audiofile-shuffled.h5", overwrite: false, chunkSize: 5)
        let shuffledFeatures = shuffledDatabase.readFeatures(0, count: 5)
        
        let noShuffleDatabase = FeatureDatabase(filePath: "test-audiofile.h5", overwrite: false, chunkSize: 5)
        let noShuffleFeatures = noShuffleDatabase.readFeatures(0, count: 5)
        
        for feature in shuffledFeatures {
            let index = noShuffleFeatures.indexOf{ $0.fileOffset == feature.fileOffset }!
            let matchingFeature = noShuffleFeatures[index]
            
            XCTAssert(feature.features[FeatureDatabase.spectrumDatasetName] == matchingFeature.features[FeatureDatabase.spectrumDatasetName])
            XCTAssert(feature.features[FeatureDatabase.spectrumFluxDatasetName] == matchingFeature.features[FeatureDatabase.spectrumFluxDatasetName])
            XCTAssert(feature.features[FeatureDatabase.peakLocationsDatasetName] == matchingFeature.features[FeatureDatabase.peakLocationsDatasetName])
            XCTAssert(feature.features[FeatureDatabase.peakHeightsDatasetName] == matchingFeature.features[FeatureDatabase.peakHeightsDatasetName])
        }
    }

}
