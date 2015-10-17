//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public struct RMSFeature : Feature {
    public var rms: Double

    public static func size() -> Int {
        return 1
    }

    public func serialize() -> RealArray {
        return [rms]
    }

    public init(audioData: RealArray) {
        rms = rmsq(audioData)
    }
}
