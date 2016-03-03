//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakHeightsFeatureGenerator : BandsFeatureGenerator {
    public let minRMS = 0.0001
    public let peaksMovingAverageSize = 5
    public let rmsMovingAverageSize = 10

    var rmsHistory: ValueArray<Double>
    var rmsHistoryIndex = 0
    var peakHistory: ValueArray<Double>
    var peakHistoryIndex = 0

    public var rmsAverage: Double
    public var peakHeights: ValueArray<Double>

    public override var data: ValueArray<Double> {
        return peakHeights
    }

    public override init(notes: Range<Int>, bandSize: Double) {
        let bandCount = Configuration.bandNotes.count
        peakHistory = ValueArray<Double>(count: bandCount * peaksMovingAverageSize, repeatedValue: 0.0)
        rmsHistory = ValueArray<Double>(count: rmsMovingAverageSize, repeatedValue: 0.0)
        rmsAverage = minRMS
        peakHeights = ValueArray<Double>(count: bandCount, repeatedValue: 0.0)
        super.init(notes: notes, bandSize: bandSize)
    }

    public override func reset() {
        let bandCount = Configuration.bandNotes.count
        for i in 0..<rmsMovingAverageSize {
            rmsHistory[i] = minRMS
        }
        for i in 0..<peakHistory.count {
            peakHistory[i] = 0
        }
        rmsAverage = minRMS
        for band in 0..<bandCount {
            peakHeights[band] = 0
        }
    }
    
    public func update(peaks: [Point], rms: Double) {
        let bandCount = Configuration.bandNotes.count
        let safeRMS = max(rms, minRMS)

        // Compute average RMS
        let rmsAverageScale = 1.0 / Double(rmsMovingAverageSize)
        rmsAverage = rmsAverage - rmsHistory[rmsHistoryIndex] * rmsAverageScale + safeRMS * rmsAverageScale
        rmsHistory[rmsHistoryIndex] = safeRMS
        rmsHistoryIndex = (rmsHistoryIndex + 1) % rmsMovingAverageSize

        // Remove oldest element from mean
        let peakAverageScale = 1.0 / Double(peaksMovingAverageSize)
        for band in 0..<bandCount {
            peakHeights[band] -= peakHistory[band + peakHistoryIndex * bandCount] * peakAverageScale
            peakHistory[band + peakHistoryIndex * bandCount] = 0
        }

        // Compute new peaks
        for peak in peaks {
            let note = freqToNote(peak.x)
            let band = bandForNote(note)
            if band >= 0 && band < bandCount {
                let newHeight = peak.y / rmsAverage
                precondition(isfinite(newHeight))
                peakHistory[band + peakHistoryIndex * bandCount] = newHeight
                peakHeights[band] += newHeight * peakAverageScale
            }
        }

        peakHistoryIndex = (peakHistoryIndex + 1) % peaksMovingAverageSize
    }
}
