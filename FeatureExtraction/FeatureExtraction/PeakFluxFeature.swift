//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Surge

public class PeakFluxFeature : PeakFeature {
    public typealias PeakArray = [Surge.Point<Double>]
    public var peakFluxes: [Double]

    public override func serialize() -> [Double] {
        return peakFluxes
    }

    public init(peaks: PeakArray, nextPeaks: PeakArray) {
        peakFluxes = [Double](count: PeakFeature.peakCount, repeatedValue: 0.0)
        super.init()

        let validPeakCount = min(PeakFeature.peakCount, peaks.count)
        for i in 0..<validPeakCount {
            let freq = peaks[i].x
            let h0 = peaks[i].y
            let h1 = heightForFrequency(freq, inPeaks: nextPeaks)
            peakFluxes[i] = h1 - h0
        }
    }

    func heightForFrequency(freq: Double, inPeaks peaks: PeakArray) -> Double {
        for point in peaks {
            if point.x == freq {
                return point.y
            }
        }
        return 0.0
    }
}
