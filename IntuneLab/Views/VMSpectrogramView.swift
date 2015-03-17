//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

import UIKit

internal class VMSpectrogramView: UIScrollView {
    let minFrequency: Float = 20
    let maxFrequency: Float = 4000

    var sampleRate: Float = 44100
    var frequencyCount: Int = 2048
    var timeScale: Float = 5 {
        didSet {
            setNeedsLayout()
        }
    }
    private var samples: UnsafePointer<Float> = UnsafePointer<Float>()
    private(set) internal var sampleCount: Int = 0

    @IBInspectable var gridColor: UIColor = UIColor.grayColor()
    @IBInspectable var lowColor: UIColor = UIColor.blueColor()
    @IBInspectable var highColor: UIColor = UIColor.blueColor()

    func setSamples(samples: UnsafePointer<Float>, count: Int) {
        self.samples = samples
        sampleCount = count
        setNeedsLayout()
    }

    internal override func layoutSubviews() {
        let timePoints = sampleCount / frequencyCount
        contentSize.height = bounds.height
        contentSize.width = CGFloat(timePoints) * CGFloat(timeScale)
        setNeedsDisplay()
    }

    override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        let fs = sampleRate / Float(frequencyCount)
        let timePoints = sampleCount / frequencyCount

        UIColor.whiteColor().setFill()
        CGContextFillRect(context, rect)

        var barRect = CGRectZero
        barRect.size.width = CGFloat(timeScale)

        for var t = 0; t < timePoints; t += 1 {
            for var fi = 0; fi < frequencyCount; fi += 1 {
                let f0 = Float(fi) * fs
                let f1 = Float(fi + 1) * fs
                let m0 = 2595.0 * log10(1 + f0/700.0)
                let m1 = 2595.0 * log10(1 + f1/700.0)
                if m0 >= maxFrequency {
                    break
                }

                let minY = bounds.height * CGFloat(m0 - minFrequency) / CGFloat(maxFrequency - minFrequency)
                let maxY = bounds.height * CGFloat(m1 - minFrequency) / CGFloat(maxFrequency - minFrequency)
                barRect.origin.y = minY
                barRect.size.height = maxY - minY

                let dbValue = 10 * log10(samples[fi + t * frequencyCount])
                setFillColorForDecibel(dbValue)
                CGContextFillRect(context, barRect)
            }
            barRect.origin.x += CGFloat(timeScale)
        }
    }

    func setFillColorForDecibel(dbValue: Float) {
        var value = (dbValue + 100) / 100
        if value < 0 {
            value = 0
        }
        VMSpectrogramView.colorLerp(lowColor, end: highColor, p: CGFloat(value)).setFill()
    }

    class func colorLerp(start: UIColor, end: UIColor, p: CGFloat) -> UIColor {
        let startComponent = CGColorGetComponents(start.CGColor)
        let endComponent = CGColorGetComponents(end.CGColor)

        let startAlpha = CGColorGetAlpha(start.CGColor)
        let endAlpha = CGColorGetAlpha(end.CGColor)

        let r = startComponent[0] + (endComponent[0] - startComponent[0]) * p
        let g = startComponent[1] + (endComponent[1] - startComponent[1]) * p
        let b = startComponent[2] + (endComponent[2] - startComponent[2]) * p
        let a = startAlpha + (endAlpha - startAlpha) * p

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
