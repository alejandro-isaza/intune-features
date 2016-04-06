//  Copyright © 2015 Venture Media. All rights reserved.

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
