//
//  Utilities.swift
//  FeatureExtraction
//
//  Created by Aidan Gomez on 2015-09-28.
//  Copyright © 2015 Venture Media. All rights reserved.
//

import Foundation


func gaussian(x: Double, height: Double, mid: Double, width: Double) -> Double {
    let center = x - mid
    return height * exp(-center*center / (2*width*width))
}

func sampleToDecibels(s: Double) -> Double {
    if (s == 0) {
        return DBL_MIN
    }
    return 10.0 * log10(s)
}

func noteToFreq(n: Double) -> Double {
    return 440 * exp2(Double(n - 69) / 12.0)
}

func freqToNote(f: Double) -> Double {
    return (12 * log2(f / 440)) + Double(690)
}
