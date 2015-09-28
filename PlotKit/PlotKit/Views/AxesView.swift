//  Copyright © 2015 Venture Media Labs. All rights reserved.

import AppKit

class AxesView: NSView {
    var insets = NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
    var lineWidth = CGFloat(1)
    var tickLength = CGFloat(5)

    var xInterval = Interval(min: 0.0, max: 1.0) {
        didSet {
            needsDisplay = true
        }
    }
    var yInterval = Interval(min: 0.0, max: 1.0) {
        didSet {
            needsDisplay = true
        }
    }

    var xTicks = [TickMark]() {
        didSet {
            needsDisplay = true
        }
    }
    var yTicks = [TickMark]() {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func drawRect(rect: CGRect) {
        let context = NSGraphicsContext.currentContext()?.CGContext
        NSColor.blackColor().setFill()

        let xAxisY = insets.bottom
        let yAxisX = insets.left

        let attributes: [String: AnyObject] = [NSFontAttributeName: NSFont(name: "Avenir Next", size: 10)!]

        // y-axis
        CGContextFillRect(context, CGRectMake(yAxisX - lineWidth/2, xAxisY, lineWidth, bounds.height - insets.top - insets.bottom))

        // x-axis
        CGContextFillRect(context, CGRectMake(yAxisX, xAxisY - lineWidth/2, bounds.width - insets.left - insets.right, lineWidth))

        let viewXInterval = Interval(min: Double(bounds.minX + insets.left), max: Double(bounds.maxX - insets.right))
        for tick in xTicks {
            let x = mapValue(tick.value, fromInterval: xInterval, toInterval: viewXInterval)
            let rect = CGRectMake(CGFloat(x - tick.lineWidth/2), insets.bottom - tickLength/2, CGFloat(tick.lineWidth), tickLength)
            CGContextFillRect(context, rect)

            let string = tick.label as NSString
            let size = string.sizeWithAttributes(attributes)
            string.drawAtPoint(NSPoint(x: CGFloat(x) - size.width/2, y: xAxisY - size.height), withAttributes: attributes)
        }

        let viewYInterval = Interval(min: Double(bounds.minY + insets.bottom), max: Double(bounds.maxY - insets.top))
        for tick in yTicks {
            let y = mapValue(tick.value, fromInterval: yInterval, toInterval: viewYInterval)
            let rect = CGRectMake(insets.left - tickLength/2, CGFloat(y - tick.lineWidth/2), tickLength, CGFloat(tick.lineWidth))
            CGContextFillRect(context, rect)

            let string = tick.label as NSString
            let size = string.sizeWithAttributes(attributes)
            string.drawAtPoint(NSPoint(x: yAxisX - size.width - tickLength, y: CGFloat(y) - size.height/2), withAttributes: attributes)
        }
    }

    private func convertToView(x x: Double, y: Double) -> CGPoint {
        let boundsXInterval = Interval(min: Double(bounds.minX), max: Double(bounds.maxX))
        let boundsYInterval = Interval(min: Double(bounds.minY), max: Double(bounds.maxY))
        return CGPoint(
            x: mapValue(x, fromInterval: xInterval, toInterval: boundsXInterval),
            y: mapValue(y, fromInterval: yInterval, toInterval: boundsYInterval))
    }
    
}
