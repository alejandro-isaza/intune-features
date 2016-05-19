// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation

public func noteToFreq(n: Double) -> Double {
    return 440 * exp2((n - 69.0) / 12.0)
}

public func freqToNote(f: Double) -> Double {
    return (12 * log2(f / 440.0)) + 69.0
}

public func parseRange(string: String) -> Range<Int>? {
    let regEx = try! NSRegularExpression(pattern: "(\\d+)\\.\\.<(\\d+)", options: NSRegularExpressionOptions())
    let range = NSRange(location: 0, length: (string as NSString).length)
    guard let match = regEx.firstMatchInString(string, options: NSMatchingOptions(), range: range) where match.numberOfRanges == 3 else {
        return nil
    }
    if let startIndex = Int((string as NSString).substringWithRange(match.rangeAtIndex(1))),
        endIndex = Int((string as NSString).substringWithRange(match.rangeAtIndex(2))) {
            return startIndex..<endIndex
    }

    return nil
}
