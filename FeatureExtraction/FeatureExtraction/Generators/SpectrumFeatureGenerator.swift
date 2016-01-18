//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public class SpectrumFeatureGenerator : BandsFeatureGenerator {
    public var bands: RealArray

    public override var data: RealArray {
        return bands
    }

    public override init(notes: Range<Int>, bandSize: Double) {
        bands = RealArray(count: notes.count)
        super.init(notes: notes, bandSize: bandSize)
    }

    public func update(spectrum data: RealArray, baseFrequency fb: Double) {
        let bandCount = notes.count

        for band in 0..<bandCount {
            let note = noteForBand(band)

            let lowerFrequency = noteToFreq(note - bandSize/2)
            let lowerBin = lowerFrequency / fb
            let lowerIndex = Int(ceil(lowerBin))

            let upperFrequency = noteToFreq(note + bandSize/2)
            let upperBin = upperFrequency / fb
            let upperIndex = Int(floor(upperBin))

            var bandValue = 0.0
            if lowerIndex <= upperIndex {
                bandValue = sum(data[lowerIndex...upperIndex])
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