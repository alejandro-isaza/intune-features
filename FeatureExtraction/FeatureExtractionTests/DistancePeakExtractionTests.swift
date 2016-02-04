//  Copyright © 2015 Venture Media. All rights reserved.

import XCTest
@testable import FeatureExtraction

import Upsurge


class DistancePeakExtractionTests: XCTestCase {    
    var count: Int = 0
    var fs = 0.0
    var fb = 0.0
    var f0 = 0.0
    
    var fft = FFTDouble(inputLength: 1)
    
    override func setUp() {
        super.setUp()
        
        count = 65536
        fs = 44100.0
        fb = fs / Double(count)
        f0 = 10 * fb
        fft = FFTDouble(inputLength: count)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSin() {
        let peakExtractor = PeakExtractor(heightCutoffMultiplier: 0.05, minimumNoteDistance: 0.5)

        let t = ValueArray<Double>((0..<count).map{ Double($0) / fs })
        let y = sin(t * 2.0 * M_PI * f0)
        let fftData = sqrt(fft.forwardMags(y))
        let fftDataPoints = (0..<fftData.count).map{ Point(x: fb * Double($0), y: fftData[$0]) }
        
        let actualPeaks = peakExtractor.process(fftDataPoints, rms: 0.5)
        let expectedPeaks: [Point] = [Point(x: f0, y: 1.0)]
        for actual in actualPeaks {
            guard let closest = expectedPeaks.minElement({ abs($0.x - actual.x) < abs($1.x - actual.x) }) else {
                XCTFail()
                return
            }

            XCTAssertEqualWithAccuracy(freqToNote(closest.x), freqToNote(actual.x), accuracy: 1)
            XCTAssert(actual.y != 0)
        }
        for expected in expectedPeaks {
            guard let closest = actualPeaks.minElement({ abs($0.x - expected.x) < abs($1.x - expected.x) }) else {
                XCTFail()
                return
            }

            XCTAssertEqualWithAccuracy(freqToNote(closest.x), freqToNote(expected.x), accuracy: 1)
            XCTAssert(closest.y != 0)
        }
    }
    
    func testLowNote() {
        let peakExtractor = PeakExtractor(heightCutoffMultiplier: 0.05, minimumNoteDistance: 0.5)

        let freq33 = noteToFreq(33)
        let freq32 = noteToFreq(32)
        let freq31 = noteToFreq(31)
        let bin33 = freq33 / fb
        let bin32 = freq32 / fb
        let bin31 = freq31 / fb
        
        let t = ValueArray<Double>((0..<count).map{ Double($0) / fs })
        let sin33 = sin(t * 2.0 * M_PI * freq33)
        let sin32 = sin(t * 2.0 * M_PI * freq32)
        let sin31 = sin(t * 2.0 * M_PI * freq31)
        
        let y = sin33 + sin32 + sin31
        let fftData = fft.forwardMags(y)
        let points = (0..<fftData.count).map{ Point(x: Double($0), y: fftData[$0]) }
        let peaks = peakExtractor.process(points, rms: 0.5)

        XCTAssertEqualWithAccuracy(peaks[0].x, bin31, accuracy: 0.5)
        XCTAssert(peaks[0].y != 0)
        XCTAssertEqualWithAccuracy(peaks[1].x, bin32, accuracy: 0.5)
        XCTAssert(peaks[1].y != 0)
        XCTAssertEqualWithAccuracy(peaks[2].x, bin33, accuracy: 0.5)
        XCTAssert(peaks[2].y != 0)
    }
    
    func testHighNote() {
        let peakExtractor = PeakExtractor(heightCutoffMultiplier: 0.05, minimumNoteDistance: 0.5)

        let freq103 = noteToFreq(103)
        let freq102 = noteToFreq(102)
        let freq101 = noteToFreq(101)
        let bin103 = freq103 / fb
        let bin102 = freq102 / fb
        let bin101 = freq101 / fb
        
        let t = ValueArray<Double>((0..<count).map{ Double($0) / fs })
        let sin103 = sin(t * 2.0 * M_PI * freq103)
        let sin102 = sin(t * 2.0 * M_PI * freq102)
        let sin101 = sin(t * 2.0 * M_PI * freq101)
        
        let y = sin103 + sin102 + sin101
        let fftData = fft.forwardMags(y)
        let points = (0..<fftData.count).map{ Point(x: Double($0), y: fftData[$0]) }
        let peaks = peakExtractor.process(points, rms: 0.5)
        
        XCTAssertEqualWithAccuracy(peaks[0].x, bin101, accuracy: 0.5)
        XCTAssert(peaks[0].y != 0)
        XCTAssertEqualWithAccuracy(peaks[1].x, bin102, accuracy: 0.5)
        XCTAssert(peaks[1].y != 0)
        XCTAssertEqualWithAccuracy(peaks[2].x, bin103, accuracy: 0.5)
        XCTAssert(peaks[2].y != 0)
    }
    
    func testMiddleNote() {
        let peakExtractor = PeakExtractor(heightCutoffMultiplier: 0.05, minimumNoteDistance: 0.5)
        
        let freq73 = noteToFreq(73)
        let freq72 = noteToFreq(72)
        let freq71 = noteToFreq(71)
        let bin73 = freq73 / fb
        let bin72 = freq72 / fb
        let bin71 = freq71 / fb
        
        let t = ValueArray<Double>((0..<count).map{ Double($0) / fs })
        let sin73 = sin(t * 2.0 * M_PI * freq73)
        let sin72 = sin(t * 2.0 * M_PI * freq72)
        let sin71 = sin(t * 2.0 * M_PI * freq71)
        
        let y = sin73 + sin72 + sin71
        let fftData = fft.forwardMags(y)
        let points = (0..<fftData.count).map{ Point(x: Double($0), y: fftData[$0]) }
        let peaks = peakExtractor.process(points, rms: 0.5)
        
        XCTAssertEqualWithAccuracy(peaks[0].x, bin71, accuracy: 0.5)
        XCTAssert(peaks[0].y != 0)
        XCTAssertEqualWithAccuracy(peaks[1].x, bin72, accuracy: 0.5)
        XCTAssert(peaks[1].y != 0)
        XCTAssertEqualWithAccuracy(peaks[2].x, bin73, accuracy: 0.5)
        XCTAssert(peaks[2].y != 0)
    }

}
