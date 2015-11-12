//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class SpectrumFluxFeature : BandsFeature {
    public var fluxes: RealArray

    public override var data: RealArray {
        return fluxes
    }

    public override init(notes: Range<Int>, bandSize: Double) {
        fluxes = RealArray(count: notes.count)
        super.init(notes: notes, bandSize: bandSize)
    }

    public func update(spectrum0 spectrum0: RealArray, spectrum1: RealArray) {
        let bandCount = notes.count
        precondition(spectrum0.count == bandCount && spectrum1.count == bandCount)

        for band in 0..<bandCount {
            fluxes[band] = spectrum1[band] - spectrum0[band]
        }
    }
}
