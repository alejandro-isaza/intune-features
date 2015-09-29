//  Copyright © 2015 Venture Media Labs. All rights reserved.

import Foundation

public struct Axis {
    public enum Orientation {
        case Vertical
        case Horizontal
    }

    public enum Position {
        case Start
        case End
        case Value(Double)
    }

    public var orientation: Orientation
    public var position = Position.Start
    public var lineWidth = CGFloat(1.0)
    public var ticks: [TickMark] = [TickMark(0)]
    public var color = NSColor.blackColor()
    public var labelAttributes: [String: AnyObject] = [NSFontAttributeName: NSFont(name: "Avenir Next", size: 10)!]

    public init(orientation: Orientation) {
        self.orientation = orientation
    }
    public init(orientation: Orientation, ticks: [TickMark]) {
        self.orientation = orientation
        self.ticks = ticks
    }
}
