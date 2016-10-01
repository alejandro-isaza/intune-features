// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation
import Upsurge

open class PeakHeightsFeatureGenerator: BandsFeatureGenerator {
    open let minRMS = 0.0001

    var rmsHistory: ValueArray<Double>
    var rmsHistoryIndex = 0

    open var rmsAverage: Double
    open var peakHeights: ValueArray<Double>

    open override var data: ValueArray<Double> {
        return peakHeights
    }

    public override init(configuration: Configuration, offsets: ValueArray<Double>? = nil, scales: ValueArray<Double>? = nil) {
        let bandCount = configuration.bandCount
        rmsHistory = ValueArray<Double>(count: configuration.rmsMovingAverageSize, repeatedValue: 0.0)
        rmsAverage = minRMS
        peakHeights = ValueArray<Double>(count: bandCount, repeatedValue: 0.0)
        super.init(configuration: configuration, offsets: offsets, scales: scales)
    }

    open override func reset() {
        let bandCount = configuration.bandCount
        for i in 0..<configuration.rmsMovingAverageSize {
            rmsHistory[i] = minRMS
        }
        rmsAverage = minRMS
        for band in 0..<bandCount {
            peakHeights[band] = 0
        }
    }
    
    open func update(_ peaks: [Point], rms: Double) {
        let bandCount = configuration.bandCount
        let safeRMS = max(rms, minRMS)

        // Compute average RMS
        let rmsAverageScale = 1.0 / Double(configuration.rmsMovingAverageSize)
        rmsAverage = rmsAverage - rmsHistory[rmsHistoryIndex] * rmsAverageScale + safeRMS * rmsAverageScale
        rmsHistory[rmsHistoryIndex] = safeRMS
        rmsHistoryIndex = (rmsHistoryIndex + 1) % configuration.rmsMovingAverageSize

        for band in 0..<bandCount {
            peakHeights[band] = 0
        }

        // Compute new peaks
        for peak in peaks {
            let note = freqToNote(peak.x)
            let band = configuration.bandForNote(note)
            if band >= 0 && band < bandCount {
                let newHeight = max(peak.y / rmsAverage, peakHeights[band])
                precondition(newHeight.isFinite)

                let offset = offsets?[band] ?? 0.0
                let scale = scales?[band] ?? 1.0
                peakHeights[band] = (newHeight - offset) / scale
            }
        }
    }
}
