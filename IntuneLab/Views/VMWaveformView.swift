//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

import UIKit

/**
  A UIView that displays waveform samples. It uses RMS (root mean square) to combine multiple samples into an
  individual pixel.
*/
public class VMWaveformView: UIView {
    var samplesPerPoint: CGFloat = 500
    var lineWidth: CGFloat = 1.0
    var lineColor: UIColor?

    private var samples: UnsafePointer<Double> = nil
    private var samplesCount: Int = 0

    public func setSamples(samples: UnsafePointer<Double>, count: Int) {
        self.samples = samples
        samplesCount = count
        setNeedsDisplay()
    }
    
    var sampleRate: CGFloat = 44100 {
        didSet {
            samplesPerPoint = duration * sampleRate / bounds.size.width
        }
    }
    
    var duration: CGFloat = 5 {
        didSet {
            samplesPerPoint = duration * sampleRate / bounds.size.width
        }
    }

    override public func drawRect(rect: CGRect) {
        lineColor?.setFill()
        lineColor?.setStroke()
        let context = UIGraphicsGetCurrentContext()
        CGContextSetLineWidth(context, lineWidth)

        let path = createPath()
        CGContextAddPath(context, path)
        CGContextFillPath(context)

        CGContextTranslateCTM(context, 0, bounds.size.height)
        CGContextScaleCTM(context, 1, -1)
        CGContextAddPath(context, path)
        CGContextFillPath(context)
    }

    private func createPath() -> CGPathRef {
        let height = bounds.size.height
        let pixelSize = contentScaleFactor
        let samplesPerPixel = Int(ceil(samplesPerPoint * pixelSize))

        let path = CGPathCreateMutable()
        var point = CGPointMake(0, height/2);
        CGPathMoveToPoint(path, nil, point.x, point.y)
        for var sampleIndex = 0; sampleIndex < samplesCount; sampleIndex += samplesPerPixel {
            // Get the RMS value for the current pixel
            var value: Double = 0.0
            let size = vDSP_Length(min(samplesPerPixel, samplesCount - sampleIndex))
            vDSP_rmsqvD(samples + sampleIndex, 1, &value, size)

            point.x += pixelSize;
            point.y = height/2 - CGFloat(value) * height/2;
            CGPathAddLineToPoint(path, nil, point.x, point.y)
        }
        CGPathAddLineToPoint(path, nil, point.x, height/2)
        CGPathCloseSubpath(path)
        return path
    }
}
