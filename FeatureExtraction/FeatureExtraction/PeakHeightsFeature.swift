//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Surge

public struct PeakHeightsFeature : Feature {
    public static let peakCount = 10
    public var peakHeights: [Double]

    public static func size() -> Int {
        return peakCount
    }

    public func serialize() -> [Double] {
        return peakHeights
    }

    public init(peaks: [Surge.Point<Double>]) {
        let validPeakCount = min(PeakHeightsFeature.peakCount, peaks.count)
        let validPeakHeights = peaks[0..<validPeakCount].map{ $0.y }
        peakHeights = [Double](count: PeakHeightsFeature.peakCount, repeatedValue: 0.0)
        peakHeights.replaceRange((0..<validPeakCount), with: validPeakHeights)
    }
}
