//  Copyright © 2015 Venture Media Labs. All rights reserved.

import XCTest
@testable import AudioKit

class AudioKitTests: XCTestCase {
    
    func testLoadWave() {
        let bundlePath = NSBundle(forClass: AudioKitTests.self).pathForResource("sin_1000Hz_-3dBFS_1s", ofType: "wav")
        guard let path = bundlePath else {
            XCTFail("Could not find wave file")
            return
        }

        guard let audioFile = AudioFile(filePath: path) else {
            XCTFail("Failed to open wave file")
            return
        }

        XCTAssertEqual(audioFile.sampleRate, 44100)

        let audioLengthInSeconds = 1.0
        let expextedFrameCount = Int64(audioLengthInSeconds * audioFile.sampleRate)
        XCTAssert(abs(audioFile.frameCount - expextedFrameCount) < 5)

        XCTAssertEqual(audioFile.currentFrame, 0)

        let readLength = 1024
        var data = [Double](count: readLength, repeatedValue: 0.0)
        let actualLength = audioFile.readFrames(&data, count: readLength)
        XCTAssertEqual(actualLength, readLength)
        XCTAssertEqual(audioFile.currentFrame, readLength)
    }
    
    func testReadMIDI() {
        let bundlePath = NSBundle(forClass: AudioKitTests.self).pathForResource("alb_esp1", ofType: "mid")
        guard let path = bundlePath else {
            XCTFail("Could not find midi file")
            return
        }

        guard let midi = MIDIFile(filePath: path) else {
            XCTFail("Could not open midi file")
            return
        }
        
        let expectedChords: [[UInt8]] = [
            [81, 57],
            [88, 64],
            [86, 62],
            [88, 64]
        ]
        
        for i in 0..<4 {
            XCTAssertEqual(midi.chords[i].notes.map{ $0.note }, expectedChords[i])
        }
    }
}
