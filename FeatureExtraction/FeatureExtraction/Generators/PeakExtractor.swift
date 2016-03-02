//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakExtractor {
    public init() {
    }

    public func process(input: [Point], rms: Double) -> [Point] {
        return findPeaks(input)
    }

    func findPeaks(input: [Point]) -> [Point] {
        var peaks = [Point]()
        
        for i in 1...input.count-2 {
            let peak = input[i]
            if input[i-1].y <= peak.y && peak.y >= input[i+1].y {
                peaks.append(peak)
            }
        }
        
        return peaks
    }
}
