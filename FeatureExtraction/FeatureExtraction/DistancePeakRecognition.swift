//
//  File.swift
//  FeatureExtraction
//
//  Created by Aidan Gomez on 2015-09-29.
//  Copyright © 2015 Venture Media. All rights reserved.
//

import Foundation

public class DistancePeakRecognition : PeakRecognition {
    let yCutoff = 0.007
    let xDeltaCutoffFactor = 1.0
    
    var baseFreq: Double = 0
    
    public init(fftPacketSize: Double, sampleRate: Double) {
        baseFreq = sampleRate / fftPacketSize
    }
    
    public func process(input: [Double], inout output: [Double]) -> Int {
        let peaks = findPeaks(input)
        let filteredPeaks = filterPeaks(peaks)
        
        output = [Double](count: input.count, repeatedValue: 0.0)
        for peak in filteredPeaks {
            output[peak.location] = input[peak.location]
        }
        
        return output.count
    }
    
    func findPeaks(input: [Double]) -> [Peak] {
        var peaks = [Peak]()
        
        for i in 1...input.count-2 {
            if input[i-1] <= input[i] && input[i] >= input[i+1] {
                let p = Peak(location: i, height: input[i])
                peaks.append(p)
            }
        }
        
        return peaks
    }
    
    func filterPeaks(input: [Peak]) -> [Peak] {
        let peaks = filterPeaksByHeight(input)
        return choosePeaks(peaks)
    }
    
    func filterPeaksByHeight(input: [Peak]) -> [Peak] {
        return input.filter { (peak: Peak) -> Bool in
            return peak.height > yCutoff
        }
    }
    
    func choosePeaks(input: [Peak]) -> [Peak] {
        var chosenPeaks = [Peak]()
        
        var currentPeakRange = Range<Int>(start: 0, end: 0)
        for peak in input {
            if currentPeakRange.contains(peak.location) {
                if let lastPeak = chosenPeaks.last where lastPeak.height < peak.height {
                    chosenPeaks.removeLast()
                    chosenPeaks.append(peak)
                    currentPeakRange = binCutoffRange(peak.location)
                }
            } else {
                chosenPeaks.append(peak)
                currentPeakRange = binCutoffRange(peak.location)
            }
        }
        
        return chosenPeaks
    }
    
    func binCutoffRange(bin: Int) -> Range<Int> {
        let binFreq = binToFreq(Double(bin))
        let binNote = freqToNote(binFreq)
        
        let freqUpperBound = xDeltaCutoffFactor * noteToFreq(binNote + 1)
        let freqLowerBound = 1 / xDeltaCutoffFactor * noteToFreq(binNote - 1)
        
        let binUpperBound = ceil(freqToBin(freqUpperBound))
        let binLowerBound = floor(freqToBin(freqLowerBound))
        return Range(start: Int(binLowerBound), end: Int(binUpperBound))
    }
    
    func binToFreq(n: Double) -> Double {
        return n * baseFreq
    }
    
    func freqToBin(f: Double) -> Double {
        return f / baseFreq
    }
}