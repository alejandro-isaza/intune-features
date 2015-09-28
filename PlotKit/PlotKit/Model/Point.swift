//  Copyright © 2015 Venture Media Labs. All rights reserved.

import Foundation

public struct Point {
    public var x: Double
    public var y: Double

    public init() {
        x = 0.0
        y = 0.0
    }
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
