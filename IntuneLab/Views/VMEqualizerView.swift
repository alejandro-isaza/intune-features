//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

import UIKit

/**
 A UIView that displays equalizer bars.
 */
public class VMEqualizerView: UIView {
    var barColor: UIColor?

    private var samples: [Float] = []
    private var samplesCount: Int = 0

    public func setSamples(samples: UnsafePointer<Float>, count: Int) {
        if count > samplesCount {
            self.samples = [Float](count: count, repeatedValue: 0)
            for var i = 0; i < count; i += 1 {
                self.samples[i] = samples[i]
            }
            samplesCount = count
        } else {
            for var i = 0; i < count; i += 1 {
                self.samples[i] = 0.9*self.samples[i] + 0.1*samples[i];
            }
        }
        setNeedsDisplay()
    }

    override public func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()

        barColor?.setFill()
        barColor?.setStroke()

        var barRect = CGRect()
        barRect.size.width = rect.width / CGFloat(samplesCount)
        for var sampleIndex = 0; sampleIndex < samplesCount; sampleIndex += 1 {
            barRect.size.height = CGFloat(samples[sampleIndex]) * rect.height
            barRect.origin.y = rect.height - barRect.height
            CGContextFillRect(context, barRect)
            barRect.origin.x += barRect.width
        }
    }
}
