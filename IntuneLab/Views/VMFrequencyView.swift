//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

import UIKit

/**
A UIView that displays frequency samples.
*/
public class VMFrequencyView: UIScrollView {
    @IBInspectable var lineColor: UIColor?
    @IBInspectable var lineWidth: CGFloat = 1.0
    @IBInspectable var matchColor: UIColor? = UIColor.greenColor()

    var frequencyZoom: CGFloat = 1 {
        didSet {
            setNeedsLayout()
        }
    }

    var binsPerPoint: CGFloat {
        get {
            let max = CGFloat(dataSize) / bounds.width
            let min = CGFloat(0.25)
            return min + (max - min) * frequencyZoom
        }
    }

    var peaks: Bool = false
    var peaksIntensity: Bool = false
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
        self.matchDataSize = 0
        setNeedsDisplay()
    }

    private var matchData: UnsafePointer<Double> = nil
    private var matchDataSize: Int = 0
    public func setMatchData(data: UnsafePointer<Double>, count: Int) {
        self.matchData = data
        self.matchDataSize = count
        setNeedsDisplay()
    }

    override public func layoutSubviews() {
        let previousOffset = contentOffset
        let previousWidth = contentSize.width
        contentInset.top = 0
        contentSize.height = bounds.height

        if binsPerPoint != 0 {
            contentSize.width = CGFloat(dataSize) / binsPerPoint
        }
        if previousWidth != 0 {
            let scale = contentSize.width / previousWidth
            contentOffset.x = scale * (previousOffset.x + bounds.width/2) - bounds.width/2
        }

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

        let start = max(0, Int(bounds.minX * binsPerPoint))
        let end = start + Int(bounds.width * binsPerPoint)
        if (peaks) {
            drawPeaks(startIndex:start, endIndex:end)
        } else {
            drawFrequency(startIndex:start, endIndex:end)
        }
    }

    private func drawFrequency(#startIndex: Int, endIndex: Int) {
        let context = UIGraphicsGetCurrentContext()
        let height = bounds.size.height
        let spacing = 1.0 / binsPerPoint

        var point = CGPointMake(bounds.minX, height);
        point.y = height - yForSampleDecibels((data).memory) * height;

        let path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, point.x, point.y)
        for var index = startIndex; index < endIndex && index < dataSize; index += 1 {
            let value = (data + index).memory
            point.y = height - yForSampleDecibels(value) * height;
            CGPathAddLineToPoint(path, nil, point.x, point.y)
            point.x += spacing;
        }
        CGContextAddPath(context, path)
        CGContextStrokePath(context)
    }

    private func drawPeaks(#startIndex: Int, endIndex: Int) {
        let context = UIGraphicsGetCurrentContext()
        let height = bounds.size.height
        let spacing = 1.0 / binsPerPoint

        var barRect = CGRect()
        barRect.origin.x = bounds.minX - (spacing / 2)
        barRect.size.width = spacing

        for var index = startIndex; index < endIndex && index < dataSize; index += 1 {
            var value = CGFloat((data + index).memory)
            var matchValue: CGFloat = 0

            if index < matchDataSize {
                matchValue = CGFloat((matchData + index).memory)
            }
            var color = value == matchValue ? matchColor : lineColor

            if peaksIntensity {
                color = color?.colorWithAlphaComponent(value)
                value = 1.0
            }
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
