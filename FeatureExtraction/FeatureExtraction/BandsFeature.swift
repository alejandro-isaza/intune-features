//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public struct BandsFeature : Feature {
    public static let notes = 24...120
    public static let bandSize = 1.0
    public var bands: RealArray

    public static func size() -> Int {
        return notes.count
    }

    public func serialize() -> RealArray {
        return bands
    }

    public init(spectrum data: RealArray, baseFrequency fb: Double) {
        let bandCount = Int(Double(BandsFeature.notes.count) / BandsFeature.bandSize)
        bands = RealArray(count: bandCount)

        for i in 0..<bandCount {
            let note = Double(BandsFeature.notes.startIndex) + Double(i) * BandsFeature.bandSize

            let lowerFrequency = noteToFreq(note - BandsFeature.bandSize/2)
            let lowerBin = lowerFrequency / fb
            let lowerIndex = Int(ceil(lowerBin))

            let upperFrequency = noteToFreq(note + BandsFeature.bandSize/2)
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

            bands[i] = bandValue
        }
    }
}
