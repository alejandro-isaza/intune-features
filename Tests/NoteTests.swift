// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import XCTest
import IntuneFeatures

class NoteTests: XCTestCase {

    func testNoteComponents() {
        let C1 = Note(midiNoteNumber: 24)
        XCTAssertFalse(C1.isSharp)
        XCTAssertEqual(C1.octave, 1)
        XCTAssertEqual(C1.note, Note.NoteType.c)

        let Cs1 = Note(midiNoteNumber: 25)
        XCTAssertTrue(Cs1.isSharp)
        XCTAssertEqual(Cs1.octave, 1)
        XCTAssertEqual(Cs1.note, Note.NoteType.cSharp)

        let E4 = Note(midiNoteNumber: 64)
        XCTAssertFalse(E4.isSharp)
        XCTAssertEqual(E4.octave, 4)
        XCTAssertEqual(E4.note, Note.NoteType.e)

        let C7 = Note(midiNoteNumber: 96)
        XCTAssertFalse(C7.isSharp)
        XCTAssertEqual(C7.octave, 7)
        XCTAssertEqual(C7.note, Note.NoteType.c)
    }

}
