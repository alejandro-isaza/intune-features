//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakLocationsFeature : PeakFeature {
    public static let frequencyScale = 1.0 / 1000.0
    public var peakLocations: RealArray

    public override var data: RealArray {
        return peakLocations
    }

    public init(peaks: [Upsurge.Point<Double>]) {
        let validPeakCount = min(PeakFeature.peakCount, peaks.count)
        let validPeakLocations = peaks[0..<validPeakCount].map{ $0.x * PeakLocationsFeature.frequencyScale }
        peakLocations = RealArray(count: PeakFeature.peakCount, repeatedValue: 0.0)
        for i in 0..<validPeakCount {
            peakLocations[i] = validPeakLocations[i]
        }
    }
}
