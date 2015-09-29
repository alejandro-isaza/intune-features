//
//  PeakExtractionTests.swift
//  FeatureExtraction
//
//  Created by Aidan Gomez on 2015-09-28.
//  Copyright © 2015 Venture Media. All rights reserved.
//

import XCTest
@testable import FeatureExtraction

import Surge
import AudioKit

class PeakExtractionTests: XCTestCase {
    var count: Int = 0
    var fs: Double = 0
    var fb: Double = 0
    var f0: Double = 0
    
    var fft: FFT = FFT(inputLength: 1)
    var peakExtractor: PeakRecognition = PeakRecognition(packetSize: 0, baseFrequency: 0)
    
    override func setUp() {
        super.setUp()
        
        count = 1024
        fs = 44100.0
        fb = fs/Double(count)
        f0 = 10 * fb
        fft = FFT(inputLength: count)
        peakExtractor = PeakRecognition(packetSize: count / 2, baseFrequency: fb)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSin() {
        let t = (0..<count).map{ Double($0) / fs }
        let y = sin(t * 2 * M_PI * f0)

        let fftData = fft.forwardMags(y)
        
        var data = [Double](count: fftData.count, repeatedValue: 0.0)
        peakExtractor.process(fftData, size: fftData.count, output: &data, capacity: data.count)
        XCTAssert(data[10] == 1)
    }
    
    func testAudio() {
        let bundle = NSBundle(forClass: PeakExtractionTests.self)
        let filePath = bundle.pathForResource("72", ofType: "wav")!
        let audioFile = AudioFile(filePath: filePath)!
        
        var audioData = [Double](count: count, repeatedValue: 0.0)
        audioFile.readFrames(&audioData, count: count)
        
        let fftData = fft.forwardMags(audioData)
        
        var data = [Double](count: fftData.count, repeatedValue: 0.0)
        peakExtractor.process(fftData, size: fftData.count, output: &data, capacity: data.count)
        XCTAssert(data[10] == 1)
    }
    
}
