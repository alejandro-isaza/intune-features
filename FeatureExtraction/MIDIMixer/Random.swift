//  Copyright © 2016 Venture Media. All rights reserved.

import Foundation


func random(min min: Int, max: Int) -> Int {
    let sign = max - min >= 0 ? 1 : -1
    return sign * Int(arc4random_uniform(UInt32(max - min))) + min
}

func random(min min: Double, max: Double) -> Double {
    return (max - min) * (Double(arc4random()) / Double(UINT32_MAX)) + min
}

func random(probability probability: Double) -> Bool {
    return arc4random_uniform(UInt32(1/probability)) == 0
}