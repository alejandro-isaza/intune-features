//  Copyright © 2016 Venture Media. All rights reserved.

import XCTest
@testable import Tracker

import FeatureExtraction
import Upsurge

class TrackerTests: XCTestCase {
    let configuration = Configuration()

    func testInitialization() {
        let onsets = [
            Onset(notes: [Note(midiNoteNumber: 72)], start: 0, wallTime: 0),
            Onset(notes: [Note(midiNoteNumber: 74)], start: 1, wallTime: 1),
        ]
        let tracker = Tracker(onsets: onsets, configuration: configuration)
        tracker.start(0, tempo: 1)

        let notes = ValueArray<Float>(count: configuration.representableNoteRange.count, repeatedValue: 0.0)
        notes[72 - configuration.representableNoteRange.startIndex] = 1.0
        tracker.update(1, notes: notes)

        XCTAssertEqual(tracker.index, 0)
    }

    func testJump() {
        let onsets = [
            Onset(notes: [Note(midiNoteNumber: 72)], start: 0, wallTime: 0),
            Onset(notes: [Note(midiNoteNumber: 74)], start: 1, wallTime: 1),
            ]
        let tracker = Tracker(onsets: onsets, configuration: configuration)
        tracker.start(0, tempo: 1)

        let notes = ValueArray<Float>(count: configuration.representableNoteRange.count, repeatedValue: 0.0)
        notes[72 - configuration.representableNoteRange.startIndex] = 1.0
        tracker.update(1, notes: notes)
        XCTAssertEqual(tracker.index, 0)

        // Move forward
        for _ in 0..<20 {
            tracker.update(0, notes: notes)
            notes[72 - configuration.representableNoteRange.startIndex] *= 0.9
        }
        
        // A perfect observation of another note should cause a jump
        notes[72 - configuration.representableNoteRange.startIndex] = 0.0
        notes[74 - configuration.representableNoteRange.startIndex] = 1.0
        tracker.update(1, notes: notes)

        XCTAssertEqual(tracker.index, 1)
    }
}
