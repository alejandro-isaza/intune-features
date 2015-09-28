//  Copyright © 2015 Venture Media Labs. All rights reserved.

import Accelerate
import Foundation

let π = M_PI

/// Compute the Gaussian function
func gaussian(x: Double, height: Double, mid: Double, width: Double) -> Double {
    let xp = x - mid
    return height * exp(-xp*xp / (2*width*width))
}

/// Generate a random number between 0 and 1
func random() -> Double {
    return Double(arc4random()) / Double(UINT32_MAX)
}
