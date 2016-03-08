//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public class BandsFeatureGenerator: FeatureGenerator {
    public let configuration: Configuration
    public let offsets: ValueArray<Double>?
    public let scales: ValueArray<Double>?

    public var data: ValueArray<Double> {
        return ValueArray<Double>()
    }

    public init(configuration: Configuration, offsets: ValueArray<Double>? = nil, scales: ValueArray<Double>? = nil) {
        precondition(offsets == nil || offsets!.count == configuration.bandCount)
        precondition(scales == nil || scales!.count == configuration.bandCount)
        self.configuration = configuration
        self.offsets = offsets
        self.scales = scales
    }

    public func reset() {}
}
