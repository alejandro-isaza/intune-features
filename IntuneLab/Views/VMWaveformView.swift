//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

import UIKit

/**
  A UIView that displays waveform samples. It uses RMS (root mean square) to combine multiple samples into an
  individual pixel.
*/
public class VMWaveformView: UIView {
    @IBInspectable var lineColor: UIColor?

    var alignment: Int = 1 // 0 = Leading, !0 = Trailing
    var lineWidth: CGFloat = 1.0
    var samplesPerPoint: CGFloat = 500

    private var samples: UnsafePointer<Float> = nil
    private var samplesCount: Int = 0
    
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
    
    public func setSamples(samples: UnsafePointer<Float>, count: Int) {
        self.samples = samples
        samplesCount = count
        setNeedsDisplay()
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
        let samplesOffset = samplesCount
        
        var x:CGFloat = 0.0
        if alignment != 0 {
            x = bounds.size.width - CGFloat(samplesOffset) / samplesPerPoint
        }
        var point = CGPointMake(x, height/2);
        
        let path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, point.x, point.y)
        
        for var sampleIndex = 0; sampleIndex < samplesCount; sampleIndex += samplesPerPixel {
            // Get the RMS value for the current pixel
            var value: Float = 0.0
            let size = vDSP_Length(min(samplesPerPixel, samplesCount - sampleIndex))
            vDSP_rmsqv(samples + sampleIndex, 1, &value, size)

            point.x += pixelSize;
            point.y = height/2 - CGFloat(value) * height/2;
            CGPathAddLineToPoint(path, nil, point.x, point.y)
        }
        CGPathAddLineToPoint(path, nil, point.x, height/2)
        CGPathCloseSubpath(path)
        return path
    }
}
