//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public class SpectrumFeature : BandsFeature {
    public var bands: RealArray

    public override var data: RealArray {
        return bands
    }

    public override init() {
        bands = RealArray(count: BandsFeature.size())
    }

    public func update(spectrum data: RealArray, baseFrequency fb: Double) {
        let bandCount = BandsFeature.size()

        for band in 0..<bandCount {
            let note = BandsFeature.noteForBand(band)

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
            
            bands[band] = bandValue
        }
    }
}