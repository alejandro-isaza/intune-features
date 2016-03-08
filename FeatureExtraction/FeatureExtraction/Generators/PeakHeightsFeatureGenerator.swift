//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakHeightsFeatureGenerator: BandsFeatureGenerator {
    public let minRMS = 0.0001

    var rmsHistory: ValueArray<Double>
    var rmsHistoryIndex = 0

    public var rmsAverage: Double
    public var peakHeights: ValueArray<Double>

    public override var data: ValueArray<Double> {
        return peakHeights
    }

    public override init(configuration: Configuration, offsets: ValueArray<Double>? = nil, scales: ValueArray<Double>? = nil) {
        let bandCount = configuration.bandCount
        rmsHistory = ValueArray<Double>(count: configuration.rmsMovingAverageSize, repeatedValue: 0.0)
        rmsAverage = minRMS
        peakHeights = ValueArray<Double>(count: bandCount, repeatedValue: 0.0)
        super.init(configuration: configuration, offsets: offsets, scales: scales)
    }

    public override func reset() {
        let bandCount = configuration.bandCount
        for i in 0..<configuration.rmsMovingAverageSize {
            rmsHistory[i] = minRMS
        }
        rmsAverage = minRMS
        for band in 0..<bandCount {
            peakHeights[band] = 0
        }
    }
    
    public func update(peaks: ValueArray<Double>, rms: Double) {
        let safeRMS = max(rms, minRMS)

        // Compute average RMS
        let rmsAverageScale = 1.0 / Double(configuration.rmsMovingAverageSize)
        rmsAverage = rmsAverage - rmsHistory[rmsHistoryIndex] * rmsAverageScale + safeRMS * rmsAverageScale
        rmsHistory[rmsHistoryIndex] = safeRMS
        rmsHistoryIndex = (rmsHistoryIndex + 1) % configuration.rmsMovingAverageSize

        // Compute new peaks
        for (band, peak) in peaks.enumerate() {
            let newHeight = peak / rmsAverage
            precondition(isfinite(newHeight))

            let offset = offsets?[band] ?? 0.0
            let scale = scales?[band] ?? 1.0
            peakHeights[band] = (newHeight - offset) / scale
        }
    }
}
