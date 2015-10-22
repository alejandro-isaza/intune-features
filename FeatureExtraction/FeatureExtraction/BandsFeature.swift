//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public class BandsFeature : Feature {
    public static let notes = 24...120
    public static let bandSize = 1.0

    public static func size() -> Int {
        return Int(Double(notes.count) / bandSize)
    }

    public var data: RealArray {
        return RealArray()
    }

    public class func bandForNote(note: Double) -> Int {
        return Int(round((note - Double(notes.startIndex)) / bandSize))
    }

    public class func noteForBand(band: Int) -> Double {
        return Double(notes.startIndex) + Double(band) * bandSize
    }
}
