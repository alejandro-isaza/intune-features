//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public class BandsFeatureGenerator: FeatureGenerator {
    public let configuration: Configuration

    public var data: ValueArray<Double> {
        return ValueArray<Double>()
    }

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func reset() {}
}
