//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakHeightsFeature : BandsFeature {
    public typealias Peak = Upsurge.Point<Double>
    
    public var peakHeights = RealArray()

    public override var data: RealArray {
        return peakHeights
    }
    
    public override init() {}

    public func update(peaks: [Peak]) {
        let bandCount = BandsFeature.size()
        peakHeights = RealArray(count: bandCount, repeatedValue: 0.0)

        for peak in peaks {
            let note = freqToNote(peak.x)
            let band = BandsFeature.bandForNote(note)
            if band >= 0 && band < bandCount && peakHeights[band] < peak.y {
                peakHeights[band] = peak.y
            }
        }
    }
}
