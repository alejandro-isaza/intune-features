//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Surge

public struct PeakLocationsFeature : Feature {
    public static let peakCount = 10
    public static let frequencyScale = 1.0 / 1000.0
    public var peakLocations: [Double]

    public static func size() -> Int {
        return peakCount
    }

    public func serialize() -> [Double] {
        return peakLocations
    }

    public init(peaks: [Surge.Point<Double>]) {
        let validPeakCount = min(PeakLocationsFeature.peakCount, peaks.count)
        let validPeakLocations = peaks[0..<validPeakCount].map{ $0.x * PeakLocationsFeature.frequencyScale }
        peakLocations = [Double](count: PeakLocationsFeature.peakCount, repeatedValue: 0.0)
        peakLocations.replaceRange((0..<validPeakCount), with: validPeakLocations)
    }
}
