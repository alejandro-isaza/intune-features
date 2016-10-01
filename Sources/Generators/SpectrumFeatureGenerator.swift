// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Upsurge

open class SpectrumFeatureGenerator: BandsFeatureGenerator {
    open var bands: ValueArray<Double>

    open override var data: ValueArray<Double> {
        return bands
    }

    public override init(configuration: Configuration, offsets: ValueArray<Double>? = nil, scales: ValueArray<Double>? = nil) {
        bands = ValueArray<Double>(count: configuration.bandCount)
        super.init(configuration: configuration, offsets: offsets, scales: scales)
    }

    open func update(spectrum data: ValueArray<Double>, baseFrequency fb: Double) {
        let bandCount = configuration.bandCount

        for band in 0..<bandCount {
            let note = configuration.noteForBand(band)

            let lowerFrequency = noteToFreq(note - 1/configuration.spectrumResolution/2)
            let lowerBin = lowerFrequency / fb
            let lowerIndex = Int(ceil(lowerBin))

            let upperFrequency = noteToFreq(note + 1/configuration.spectrumResolution/2)
            let upperBin = upperFrequency / fb
            let upperIndex = Int(floor(upperBin))

            var bandValue = 0.0
            if lowerIndex <= upperIndex {
                bandValue = sum(data[lowerIndex...upperIndex])
            }

            if lowerIndex > 0 {
                let lowerWeight = Double(lowerIndex) - lowerBin
                bandValue += data[lowerIndex - 1] * lowerWeight
            }

            if upperIndex < data.count {
                let upperWeight = upperBin - Double(upperIndex)
                bandValue += data[upperIndex + 1] * upperWeight
            }

            let offset = offsets?[band] ?? 0.0
            let scale = scales?[band] ?? 1.0
            bands[band] = (bandValue - offset) / scale
        }
    }
}
