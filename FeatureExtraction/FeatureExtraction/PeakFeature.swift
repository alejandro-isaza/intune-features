//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public class PeakFeature : Feature {
    public static let peakCount = 5

    public static func size() -> Int {
        return peakCount
    }

    public var data: RealArray {
        return RealArray(count: PeakFeature.peakCount, repeatedValue: 0.0)
    }
}
