//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

public class PeakFeature : Feature {
    public static let peakCount = 5

    public static func size() -> Int {
        return peakCount
    }

    public func serialize() -> [Double] {
        return [Double](count: PeakFeature.peakCount, repeatedValue: 0.0)
    }
}
