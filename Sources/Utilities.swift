// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation

public func noteToFreq(_ n: Double) -> Double {
    return 440 * exp2((n - 69.0) / 12.0)
}

public func freqToNote(_ f: Double) -> Double {
    return (12 * log2(f / 440.0)) + 69.0
}

public func parseRange(_ string: String) -> CountableRange<Int>? {
    let regEx = try! NSRegularExpression(pattern: "(\\d+)\\.\\.<(\\d+)", options: NSRegularExpression.Options())
    let range = NSRange(location: 0, length: (string as NSString).length)
    guard let match = regEx.firstMatch(in: string, options: NSRegularExpression.MatchingOptions(), range: range) , match.numberOfRanges == 3 else {
        return nil
    }
    if let startIndex = Int((string as NSString).substring(with: match.rangeAt(1))),
        let endIndex = Int((string as NSString).substring(with: match.rangeAt(2))) {
            return startIndex..<endIndex
    }

    return nil
}
