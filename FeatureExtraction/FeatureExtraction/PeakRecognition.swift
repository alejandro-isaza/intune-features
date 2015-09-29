//
//  PeakRecognition.swift
//  FeatureExtraction
//
//  Created by Aidan Gomez on 2015-09-28.
//  Copyright © 2015 Venture Media. All rights reserved.
//

import Foundation

import Surge

protocol PeakRecognition {
    func process(input: [Double], inout output: [Double]) -> Int
}


public class AlPeak : PeakRecognition {
    var _packetSize: Int
    var _baseFrequency: Double
    var _peakSlopes: [(Int, Double)]
    
    var _slopeCurveMax: Double = 0.3
    var _slopeCurveMin: Double = 0
    var _slopeCurveWidth: Double = 5000
    var _cutoffValue: Double = -80.00
    
    public init(packetSize: Int, baseFrequency: Double) {
        _packetSize = packetSize
        _baseFrequency = baseFrequency
        _peakSlopes = [(Int, Double)]()
    }
    
    public func process(input: [Double], inout output: [Double]) -> Int {
        assert(input.count == _packetSize)
        assert(output.count >= _packetSize)
        
        // Compute peak slopes
        _peakSlopes.removeAll()
        var lastPeakIndex = 0
        var lastValleyIndex = 0
        for (var i = 1; i < input.count - 1; i += 1) {
            if (input[i-1] >= input[i] && input[i+1] > input[i]) {
                // valley
                if (lastValleyIndex < lastPeakIndex && lastPeakIndex < i) {
                    addPeak(lastValleyIndex, leftValue: input[lastValleyIndex], peakIndex: lastPeakIndex, peakValue: input[lastPeakIndex], rightIndex: i, rightValue: input[i])
                }
                lastValleyIndex = i
            } else if (input[i-1] < input[i] && input[i+1] <= input[i]) {
                // peak
                lastPeakIndex = i
            }
        }
        addPeak(lastValleyIndex, leftValue: input[lastValleyIndex], peakIndex: lastPeakIndex, peakValue: input[lastPeakIndex], rightIndex: input.count-1, rightValue: input[input.count-1])
        
        // Generate peaks
        output = [Double](count: output.count, repeatedValue: 0.0)
        for (var i = 0; i < _peakSlopes.count; i += 1) {
            let index = _peakSlopes[i].0
            let slope = _peakSlopes[i].1
            let frequency = _baseFrequency * Double(index)
            let slopeLimit = gaussian(frequency, height: _slopeCurveMax - _slopeCurveMin, mid: 0.0, width: _slopeCurveWidth) + _slopeCurveMin
            
            if (slope >= slopeLimit) {
                output[index] = 1
            }
        }
        
        return input.count
    }
    
    func addPeak(leftIndex: Int, leftValue: Double, peakIndex: Int, peakValue: Double, rightIndex: Int, rightValue: Double) {
        let peakValueDB = sampleToDecibels(peakValue)
        if (peakValueDB < _cutoffValue) {
            return
        }
        
        let leftValueDB = sampleToDecibels(leftValue)
        let rightValueDB = sampleToDecibels(rightValue)
        
        let leftFrequency = Double(leftIndex) * _baseFrequency
        let peakFrequency = Double(peakIndex) * _baseFrequency
        let rightFrequency = Double(rightIndex) * _baseFrequency
        
        
        let leftSlope = (peakValueDB - leftValueDB) / (peakFrequency - leftFrequency)
        let rightSlope = (peakValueDB - rightValueDB) / (rightFrequency - peakFrequency)
        
        let slope = min(leftSlope, rightSlope)
        _peakSlopes.append((peakIndex, slope))
    }
}

struct Peak {
    var location: Int
    var height: Double
}

public class DistancePeak : PeakRecognition {
    let yCutoff = 0.001
    let xDeltaCutoffFactor = 0.9
    let fDeltaFactor = exp2(1.0 / 12.0)
    
    var baseFreq: Double = 0
    
    var peaks = [Peak]()
    
    public init(fftPacketSize: Double, sampleRate: Double) {
        baseFreq = sampleRate / fftPacketSize
    }
    
    public func process(input: [Double], inout output: [Double]) -> Int {
        findPeaks(input)
        filterPeaks()
        
        output = [Double](count: input.count, repeatedValue: 0.0)
        for peak in peaks {
            output[peak.location] = 1
        }
        
        return output.count
    }
    
    func findPeaks(input: [Double]) {
        for i in 1...input.count-2 {
            if input[i-1] <= input[i] && input[i] >= input[i+1] {
                let p = Peak(location: i, height: input[i])
                peaks.append(p)
            }
        }
    }
    
    func filterPeaks() {
        peaks = peaks.filter { (peak: Peak) -> Bool in
            return peak.height > yCutoff
        }
        
        var cutoffRange = Range<Int>(start: 0, end: 0)
        var limit = peaks.count
        for var i = 0; i < limit; ++i {
            let peak = peaks[i]
            if cutoffRange.contains(peak.location) {
                let peakRange = binCutoffRange(peak.location)
                let rangeStart = [cutoffRange.startIndex, peakRange.startIndex].minElement()!
                let rangeEnd = [cutoffRange.endIndex, peakRange.endIndex].maxElement()!
                cutoffRange = Range<Int>(start: rangeStart, end: rangeEnd)
                
                // Remove smaller peak
                peak.height > peaks[i - 1].height ? peaks.removeAtIndex(i - 1) : peaks.removeAtIndex(i)
                --limit
                --i
            }
            else {
                cutoffRange = binCutoffRange(peak.location)
            }
        }
    }
    
    func binCutoffRange(n: Int) -> Range<Int> {
        let f = binToFreq(Double(n))
        let note = freqToNote(f)
        let upperBoundFreq = noteToFreq(note + 1)
        let lowerBoundFreq = noteToFreq(note - 1)
        assert(upperBoundFreq == xDeltaCutoffFactor * f * fDeltaFactor)
        assert(lowerBoundFreq == f / (xDeltaCutoffFactor * fDeltaFactor))
        let upperBound = floor(freqToBin(upperBoundFreq))
        let lowerBound = ceil(freqToBin(lowerBoundFreq))
        return Range(start: Int(lowerBound), end: Int(upperBound))
    }
    
    func binToFreq(n: Double) -> Double {
        return n * baseFreq
    }
    
    func freqToBin(f: Double) -> Double {
        return f / baseFreq
    }
}
