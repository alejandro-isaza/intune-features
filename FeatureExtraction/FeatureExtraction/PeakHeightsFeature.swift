//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakHeightsFeature : PeakFeature {
    public var peakHeights: RealArray

    public override var data: RealArray {
        return peakHeights
    }

    public init(peaks: [Upsurge.Point<Double>]) {
        let validPeakCount = min(PeakFeature.peakCount, peaks.count)
        let validPeakHeights = peaks[0..<validPeakCount].map{ $0.y }
        peakHeights = RealArray(count: PeakFeature.peakCount, repeatedValue: 0.0)
        for i in 0..<validPeakCount {
            peakHeights[i] = validPeakHeights[i]
        }
    }
}
