//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Surge

public struct RMSFeature : Feature {
    public var rms: Double

    public static func size() -> Int {
        return 1
    }

    public func serialize() -> [Double] {
        return [rms]
    }

    public init(audioData: [Double]) {
        rms = rmsq(audioData)
    }
}
