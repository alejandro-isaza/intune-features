//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

import UIKit

/**
A UIView that displays frequency samples.
*/
public class VMFrequencyView: UIView {
    @IBInspectable var lineColor: UIColor?

    var lineWidth: CGFloat = 1.0

    /// The minimum decibel value to display
    var decibelGround: Double = -100 {
        didSet {
            setNeedsDisplay()
        }
    }

    private var data: UnsafePointer<Double> = nil
    private var dataSize: Int = 0

    public func setData(data: UnsafePointer<Double>, count: Int) {
        self.data = data
        self.dataSize = count
        setNeedsDisplay()
    }

    override public func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()

        backgroundColor?.setFill()
        CGContextFillRect(context, rect)

        lineColor?.setFill()
        lineColor?.setStroke()
        CGContextSetLineWidth(context, lineWidth)

        let path = createPath()
        CGContextAddPath(context, path)
        CGContextStrokePath(context)
    }

    private func createPath() -> CGPathRef {
        let showSize = dataSize
        let height = bounds.size.height
        let spacing = bounds.width / CGFloat(showSize)

        var point = CGPointMake(0.0, height);

        let path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, point.x, point.y)

        for var index = 0; index < showSize; index += 1 {
            let value = (data + index).memory
            point.y = height - yForSampleDecibels(value) * height;
            CGPathAddLineToPoint(path, nil, point.x, point.y)
            point.x += spacing;
        }
        CGPathAddLineToPoint(path, nil, point.x, height)

        return path
    }

    func yForSampleDecibels(v: Double) -> CGFloat {
        let dbValue = 10 * log10(v + DBL_EPSILON)
        var value = (dbValue - decibelGround) / -decibelGround
        if value < 0 {
            value = 0
        }
        return CGFloat(value)
    }
}
