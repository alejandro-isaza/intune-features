//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class FluxFeatureGenerator: BandsFeatureGenerator {
    public var fluxes: ValueArray<Double>

    public override var data: ValueArray<Double> {
        return fluxes
    }

    public override init(configuration: Configuration) {
        fluxes = ValueArray<Double>(count: configuration.bandCount)
        super.init(configuration: configuration)
    }

    public func update(data0 data0: ValueArray<Double>, data1: ValueArray<Double>) {
        let bandCount = configuration.bandCount
        precondition(data0.count == bandCount && data1.count == bandCount)

        for band in 0..<bandCount {
            fluxes[band] = data1[band] - data0[band]
        }
    }
}
