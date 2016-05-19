// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation
import Upsurge

public class FluxFeatureGenerator: BandsFeatureGenerator {
    public var fluxes: ValueArray<Double>

    public override var data: ValueArray<Double> {
        return fluxes
    }

    public override init(configuration: Configuration, offsets: ValueArray<Double>? = nil, scales: ValueArray<Double>? = nil) {
        fluxes = ValueArray<Double>(count: configuration.bandCount)
        super.init(configuration: configuration, offsets: offsets, scales: scales)
    }

    public func update(data0 data0: ValueArray<Double>, data1: ValueArray<Double>) {
        let bandCount = configuration.bandCount
        precondition(data0.count == bandCount && data1.count == bandCount)

        for band in 0..<bandCount {
            let offset = offsets?[band] ?? 0.0
            let scale = scales?[band] ?? 1.0
            fluxes[band] = (data1[band] - data0[band] - offset) / scale
        }
    }
}
