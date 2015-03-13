//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

import UIKit

/**
 A UIView that displays equalizer bars.
 */
public class VMEqualizerView: UIView {
    var gridColor: UIColor = UIColor.blackColor()
    var barColor: UIColor = UIColor.blueColor()

    private var samples: [Float] = []
    private var samplesCount: Int = 0

    public func setSamples(newSamples: UnsafePointer<Float>, count: Int) {
        if count > samplesCount {
            self.samples = [Float](count: count, repeatedValue: 0)
            for var i = 0; i < count; i += 1 {
                samples[i] = newSamples[i]
            }
            samplesCount = count
        } else {
            for var i = 0; i < count; i += 1 {
                if newSamples[i] >= 1 {
                    samples[i] = 1
                } else if newSamples[i] > samples[i] {
                    samples[i] = newSamples[i]
                } else if samples[i] >= 0.001 {
                    samples[i] -= 0.001
                } else {
                    samples[i] = 0
                }
            }
        }
        setNeedsDisplay()
    }

    override public func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        let barBounds = CGRectInset(bounds, 20, 20)

        gridColor.setStroke()
        CGContextSetLineWidth(context, 1)
        CGContextStrokeRect(context, barBounds)

        barColor.setFill()
        var barRect = CGRect()
        barRect.origin.x = barBounds.minX
        barRect.size.width = bounds.width / CGFloat(samplesCount)
        for var sampleIndex = 0; sampleIndex < samplesCount; sampleIndex += 1 {
            barRect.size.height = CGFloat(samples[sampleIndex]) * barBounds.height
            barRect.origin.y = barBounds.maxY - barRect.height
            CGContextFillRect(context, barRect)
            barRect.origin.x += barRect.width
        }
    }
}
