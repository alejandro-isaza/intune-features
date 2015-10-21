//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class RMSFeature : Feature {
    public var rms: Real = 0.0

    public static func size() -> Int {
        return 1
    }

    public var data: RealArray {
        return [rms]
    }

    public func update(audioData: RealArray) {
        rms = rmsq(audioData)
    }

    public init() {}
}
