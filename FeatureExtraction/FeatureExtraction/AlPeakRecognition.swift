//
//  AlPeak.swift
//  FeatureExtraction
//
//  Created by Aidan Gomez on 2015-09-29.
//  Copyright © 2015 Venture Media. All rights reserved.
//

import Foundation

public class AlPeakRecognition : PeakRecognition {
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