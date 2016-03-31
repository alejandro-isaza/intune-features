//  Copyright © 2016 Venture Media. All rights reserved.

import Foundation

/// Generate a pseudorandom number sampled from a discrete uniform distribution
public func randUniform(min: Int, _ max: Int) -> Int {
    return Int(arc4random_uniform(UInt32(max - min + 1))) + min
}

/// Generate a pseudorandom number sampled from a continuous uniform distribution
public func randUniform(min: Double, _ max: Double) -> Double {
    return (max - min) * Double(Double(arc4random()) / Double(UINT32_MAX)) + min
}

/// Generate a pseudorandom number sampled from a normal distribution
public func randNormal(mean: Double, _ stdDev: Double) -> Double {
    var x1 = 0.0, x2 = 0.0, w = 0.0
    repeat {
        x1 = randUniform(-1.0, 1.0)
        x2 = randUniform(-1.0, 1.0)
        w = x1 * x1 + x2 * x2
    } while w >= 1.0

    w = sqrt((-2.0 * log(w)) / w)
    return mean + x1 * w * stdDev
}
