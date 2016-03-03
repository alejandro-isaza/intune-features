//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakHeightsFeatureGenerator : BandsFeatureGenerator {
    public let minRMS = 0.0001
    public let peaksMovingAverageSize = 5
    public let rmsMovingAverageSize = 10

    public var rmsHistory: ValueArray<Double>
    public var peakHistory: ValueArray<Double>
    public var peakHeights: ValueArray<Double>

    public override var data: ValueArray<Double> {
        return peakHeights
    }

    public override init(notes: Range<Int>, bandSize: Double) {
        peakHeights = ValueArray<Double>(count: notes.count)
        peakHistory = ValueArray<Double>(count: notes.count * peaksMovingAverageSize, repeatedValue: 0.0)
        rmsHistory = ValueArray<Double>(count: rmsMovingAverageSize, repeatedValue: 0.0)
        super.init(notes: notes, bandSize: bandSize)
    }

    public override func reset() {
        for i in 0..<rmsMovingAverageSize {
            rmsHistory[i] = minRMS
        }
        for i in 0..<peakHistory.count {
            peakHistory[i] = 0
        }
    }
    
    public func update(peaks: [Point], rms: Double) {
        let bandCount = notes.count
        let safeRMS = max(rms, minRMS)

        // Shift RMS values
        withPointer(&rmsHistory) { pointer in
            pointer.assignFrom(pointer + 1, count: rmsMovingAverageSize - 1)
        }

        // Shift peaks
        withPointer(&peakHistory) { pointer in
            pointer.assignFrom(pointer + bandCount, count: (peaksMovingAverageSize  - 1) * bandCount)
        }
        for i in 0..<bandCount {
            peakHistory[(peaksMovingAverageSize - 1) * bandCount + i] = 0
        }

        // Compute average RMS
        rmsHistory[rmsMovingAverageSize - 1] = safeRMS
        let rmsAverage = mean(rmsHistory)
        precondition(rmsAverage >= minRMS)

        // Compute new peaks
        for peak in peaks {
            let note = freqToNote(peak.x)
            let band = bandForNote(note)
            if band >= 0 && band < bandCount {
                let newHeight = peak.y / rmsAverage
                precondition(isfinite(newHeight))
                peakHistory[(peaksMovingAverageSize - 1) * bandCount + band] = newHeight
            }
        }

        // Compute peak averages
        for i in 0..<bandCount {
            let peakMean = mean(ValueArraySlice(base: peakHistory, startIndex: i, endIndex: (peaksMovingAverageSize - 1) * bandCount + i, step: bandCount))
            precondition(isfinite(peakMean))
            peakHeights[i] = peakMean
        }
    }
}
