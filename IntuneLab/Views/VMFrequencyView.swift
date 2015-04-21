//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

import UIKit

/**
A UIView that displays frequency samples.
*/
public class VMFrequencyView: UIView {
    @IBInspectable var lineColor: UIColor?
    @IBInspectable var lineWidth: CGFloat = 1.0
    @IBInspectable var matchColor: UIColor? = UIColor.greenColor()

    var sampleRate = 44100.0
    var maxFrequency = 6000.0

    var peaks: Bool = false
    var peakWidth: CGFloat = 3.0

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

    private var matchData: UnsafePointer<Double> = nil
    private var matchDataSize: Int = 0
    public func setMatchData(data: UnsafePointer<Double>, count: Int) {
        self.matchData = data
        self.matchDataSize = count
        setNeedsDisplay()
    }

    override public func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()

        backgroundColor?.setFill()
        CGContextFillRect(context, rect)

        if dataSize == 0 {
            return
        }

        lineColor?.setFill()
        lineColor?.setStroke()
        CGContextSetLineWidth(context, lineWidth)

        if (peaks) {
            drawPeaks()
        } else {
            drawFrequency()
        }
    }

    private func drawFrequency() {
        let context = UIGraphicsGetCurrentContext()

        let windowSize = 2*dataSize
        let baseFrequency = sampleRate / Double(windowSize)
        let maxIndex = Int(maxFrequency / baseFrequency)

        let height = bounds.size.height
        let spacing = bounds.width / CGFloat(maxIndex)
        var point = CGPointMake(0.0, height);

        let path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, point.x, point.y)

        for var index = 0; index < maxIndex; index += 1 {
            let value = (data + index).memory
            point.y = height - yForSampleDecibels(value) * height;
            CGPathAddLineToPoint(path, nil, point.x, point.y)
            point.x += spacing;
        }
        CGPathAddLineToPoint(path, nil, point.x, height)

        CGContextAddPath(context, path)
        CGContextStrokePath(context)
    }

    private func drawPeaks() {
        let context = UIGraphicsGetCurrentContext()

        let windowSize = 2*dataSize
        let baseFrequency = sampleRate / Double(windowSize)
        let maxIndex = Int(maxFrequency / baseFrequency)

        let height = bounds.size.height
        let spacing = bounds.width / CGFloat(maxIndex)
        var point = CGPointMake(0.0, height);

        var barRect = CGRect()
        barRect.origin.x = bounds.minX - (spacing / 2)
        barRect.size.width = spacing

        for var index = 0; index < maxIndex; index += 1 {
            let value = CGFloat((data + index).memory)
            var matchValue: CGFloat = 0

            if (index < matchDataSize) {
                matchValue = CGFloat((matchData + index).memory)
            }
            let color = value == matchValue ? matchColor : lineColor
            color?.setFill()

            barRect.size.height = value * bounds.height
            CGContextFillRect(context, barRect);

            barRect.origin.x += barRect.width
        }
    }

    private func yForSampleDecibels(v: Double) -> CGFloat {
        let dbValue = 10 * log10(v + DBL_EPSILON)
        var value = (dbValue - decibelGround) / -decibelGround
        if value < 0 {
            value = 0
        }
        return CGFloat(value)
    }
}
