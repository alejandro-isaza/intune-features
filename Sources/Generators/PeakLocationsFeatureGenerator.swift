// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation
import Upsurge

open class PeakLocationsFeatureGenerator: BandsFeatureGenerator {
    open var peakLocations: ValueArray<Double>

    open override var data: ValueArray<Double> {
        return peakLocations
    }

    public override init(configuration: Configuration, offsets: ValueArray<Double>? = nil, scales: ValueArray<Double>? = nil) {
        peakLocations = ValueArray<Double>(count: configuration.bandCount)
        super.init(configuration: configuration, offsets: offsets, scales: scales)
    }

    open func update(_ peaks: [Point]) {
        let bandCount = configuration.bandCount
        
        var peaksByBand = [Int: Point]()
        for peak in peaks {
            let note = freqToNote(peak.x)
            let band = configuration.bandForNote(note)
            guard band >= 0 && band < bandCount else {
                continue
            }

            if let existingPeak = peaksByBand[band] {
                if existingPeak.y < peak.y {
                    peaksByBand[band] = peak
                }
            } else {
                peaksByBand[band] = peak
            }
        }

        for band in 0..<bandCount {
            let note = configuration.noteForBand(band)
            if let peak = peaksByBand[band] {
                let peakN = freqToNote(peak.x)
                peakLocations[band] = 1.0 - abs(note - peakN)
            } else {
                peakLocations[band] = 0.0
            }
        }
    }
}
