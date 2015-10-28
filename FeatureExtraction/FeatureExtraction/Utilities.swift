//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

public func noteToFreq(n: Double) -> Double {
    return 440 * exp2((n - 69.0) / 12.0)
}

public func freqToNote(f: Double) -> Double {
    return (12 * log2(f / 440.0)) + 69.0
}
