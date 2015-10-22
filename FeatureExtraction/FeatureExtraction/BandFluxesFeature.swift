//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class BandFluxsFeature : BandsFeature {
    public var fluxes: RealArray

    public override var data: RealArray {
        return fluxes
    }

    public override init(notes: Range<Int>, bandSize: Double) {
        fluxes = RealArray(count: notes.count)
        super.init(notes: notes, bandSize: bandSize)
    }

    public func update(bands0 bands0: RealArray, bands1: RealArray) {
        let bandCount = notes.count
        precondition(bands0.count == bandCount && bands1.count == bandCount)

        for band in 0..<bandCount {
            fluxes[band] = bands1[band] - bands0[band]
        }
    }
}
