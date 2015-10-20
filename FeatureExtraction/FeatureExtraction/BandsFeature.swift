//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public struct BandsFeature : Feature {
    public static let notes = 24...120
    public var bands: RealArray

    public static func size() -> Int {
        return notes.count
    }

    public func serialize() -> RealArray {
        return bands
    }

    public init(spectrum data: RealArray, baseFrequency fb: Double) {
        bands = RealArray(capacity: BandsFeature.notes.count)

        var i = 0
        for note in BandsFeature.notes {
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

            bands[i++] = bandValue
        }
    }
}
