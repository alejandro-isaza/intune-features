//  Copyright © 2015 Venture Media. All rights reserved.

import XCTest
import FeatureExtraction

class UtilitiesTests: XCTestCase {

    func testNoteComponents() {
        XCTAssertEqual(noteComponents(24).0, 1)
        XCTAssertEqual(noteComponents(24).1, Note.C)

        XCTAssertEqual(noteComponents(25).0, 1)
        XCTAssertEqual(noteComponents(25).1, Note.Cs)

        XCTAssertEqual(noteComponents(64).0, 4)
        XCTAssertEqual(noteComponents(64).1, Note.E)

        XCTAssertEqual(noteComponents(96).0, 7)
        XCTAssertEqual(noteComponents(96).1, Note.C)
    }

}
