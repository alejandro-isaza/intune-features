//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Surge

public class PeakHeightsFeature : PeakFeature {
    public var peakHeights: [Double]

    public override func serialize() -> [Double] {
        return peakHeights
    }

    public init(peaks: [Surge.Point<Double>]) {
        let validPeakCount = min(PeakFeature.peakCount, peaks.count)
        let validPeakHeights = peaks[0..<validPeakCount].map{ $0.y }
        peakHeights = [Double](count: PeakFeature.peakCount, repeatedValue: 0.0)
        peakHeights.replaceRange((0..<validPeakCount), with: validPeakHeights)
    }
}
