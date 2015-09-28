//  Copyright © 2015 Venture Media Labs. All rights reserved.

import Foundation

public struct TickMark {
    public var value: Double
    public var label: String
    public var lineWidth = 1.0

    public init(_ value: Double) {
        self.value = value
        label = String(format: "%.3g", arguments: [value])
    }

    public init(_ value: Int) {
        self.value = Double(value)
        label = String(format: "%.3g", arguments: [value])
    }
}
