//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Surge

public class BandExtractor {
    class public func process(spectrumData data: [Double], notes: Range<Int>, baseFrequency fb: Double) -> [Double] {
        var bands = [Double]()
        for note in notes {
            let lowerFrequency = noteToFreq(Double(note) - 0.5)
            let lowerBin = lowerFrequency / fb
            let lowerIndex = Int(ceil(lowerBin))

            let upperFrequency = noteToFreq(Double(note) + 0.5)
            let upperBin = upperFrequency / fb
            let upperIndex = Int(floor(upperBin))

            var bandValue = 0.0
            if lowerIndex <= upperIndex {
                bandValue = sum(data, range: lowerIndex...upperIndex)
            }

            if lowerIndex > 0 {
                let lowerWeight = 1.0 + (lowerBin - Double(lowerIndex))
                bandValue += data[lowerIndex - 1] * lowerWeight
            }

            if upperIndex < data.count {
                let upperWeight = upperBin - Double(upperIndex)
                bandValue += data[upperIndex + 1] * upperWeight
            }

            bands.append(bandValue)
        }
        return bands
    }
}
