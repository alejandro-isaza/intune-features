//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class BandFluxsFeature : BandsFeature {
    public var fluxes: RealArray = RealArray()

    public override var data: RealArray {
        return fluxes
    }

    public override init() {}

    public func update(bands0 bands0: RealArray, bands1: RealArray) {
        let bandCount = BandsFeature.size()
        precondition(bands0.count == bandCount && bands1.count == bandCount)
        fluxes = RealArray(count: bands0.count)

        for band in 0..<bandCount {
            fluxes[band] = bands1[band] - bands0[band]
        }
    }
}
