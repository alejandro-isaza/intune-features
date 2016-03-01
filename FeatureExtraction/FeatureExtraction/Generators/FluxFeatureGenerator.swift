//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class FluxFeatureGenerator : BandsFeatureGenerator {
    public var fluxes: ValueArray<Double>

    public override var data: ValueArray<Double> {
        return fluxes
    }

    public override init(notes: Range<Int>, bandSize: Double) {
        fluxes = ValueArray<Double>(count: notes.count)
        super.init(notes: notes, bandSize: bandSize)
    }

    public func update(data0 data0: ValueArray<Double>, data1: ValueArray<Double>) {
        let bandCount = notes.count
        precondition(data0.count == bandCount && data1.count == bandCount)

        for band in 0..<bandCount {
            fluxes[band] = data1[band] - data0[band]
        }
    }
}
