// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

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
