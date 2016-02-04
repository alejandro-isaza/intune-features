//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class SpectrumFluxFeatureGenerator : BandsFeatureGenerator {
    public var fluxes: ValueArray<Double>

    public override var data: ValueArray<Double> {
        return fluxes
    }

    public override init(notes: Range<Int>, bandSize: Double) {
        fluxes = ValueArray<Double>(count: notes.count)
        super.init(notes: notes, bandSize: bandSize)
    }

    public func update(spectrum0 spectrum0: ValueArray<Double>, spectrum1: ValueArray<Double>) {
        let bandCount = notes.count
        precondition(spectrum0.count == bandCount && spectrum1.count == bandCount)

        for band in 0..<bandCount {
            fluxes[band] = spectrum1[band] - spectrum0[band]
        }
    }
}
