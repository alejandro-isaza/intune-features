//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public class BandsFeature : Feature {
    public let notes: Range<Int>
    public let bandSize: Double

    public var data: RealArray {
        return RealArray()
    }

    public init(notes: Range<Int>, bandSize: Double) {
        self.notes = notes
        self.bandSize = bandSize
    }

    public func bandForNote(note: Double) -> Int {
        return Int(round((note - Double(notes.startIndex)) / bandSize))
    }

    public func noteForBand(band: Int) -> Double {
        return Double(notes.startIndex) + Double(band) * bandSize
    }
}
