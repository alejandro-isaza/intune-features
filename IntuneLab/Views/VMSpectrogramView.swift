//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

import UIKit

internal class VMSpectrogramView: UIScrollView {
    /// The sample rate of the audio data
    var sampleRate: Float = 44100

    /// The maximum frequency to display
    let minFrequency: Float = 20

    /// The minimum frequency to display
    let maxFrequency: Float = 8000

    /// The minimum decibel value to display
    var decibelGround: Double = -100 {
        didSet {
            setNeedsDisplay()
        }
    }

    /// The length of a slice in seconds
    var sampleTimeLength: NSTimeInterval = 0.025

    /// The length of data in seconds
    var timeLength: NSTimeInterval {
        get {
            let timePoints = NSTimeInterval(sampleCount) / NSTimeInterval(frequencyBinCount)
            return timePoints * sampleTimeLength
        }
    }

    /// The time-axis range in seconds
    var timeScale: NSTimeInterval = 10 {
        didSet {
            if timeScale < 0.05 {
                timeScale = 0.05
            }
            setNeedsLayout()
        }
    }

    /// The width of a time slice in points
    var sliceWidth: CGFloat {
        get {
            return bounds.width * CGFloat(sampleTimeLength / timeScale)
        }
    }

    /// The number of frequency bins in the samples
    var frequencyBinCount: Int = 2048

    /// Time slice to highlight
    var highlightTimeIndex: Int = 0

    /// To convert pinch regocnizer scale into 'zoom'
    private var recognizerScaleBegan = CGFloat()
    private var timeScaleBegan = NSTimeInterval()

    @IBInspectable var gridColor: UIColor = UIColor.grayColor()
    @IBInspectable var peakColor: UIColor = UIColor.blackColor().colorWithAlphaComponent(0.25)
    @IBInspectable var hueMin: CGFloat = 240
    @IBInspectable var hueMax: CGFloat = 0
    @IBInspectable var saturationMin: CGFloat = 0.5
    @IBInspectable var saturationMax: CGFloat = 1.0

    private(set) internal var samples: UnsafePointer<Double> = nil
    private(set) internal var sampleCount: Int = 0
    func setSamples(samples: UnsafePointer<Double>, count: UInt) {
        self.samples = samples
        sampleCount = Int(count)
        setNeedsLayout()
    }

    var peaks: UnsafePointer<Double> = nil {
        didSet {
            setNeedsDisplay()
        }
    }

    enum Scale {
        case Linear
        case Mel
    }
    var yScale: Scale = .Mel

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    func timeIndexAtLocation(location: CGPoint) -> UInt {
        if sampleCount == 0 {
            return 0
        }

        let sampleOffsetInPoints = location.x
        let sampleWidth = bounds.width * CGFloat(sampleTimeLength / timeScale)
        var sampleOffset = floor(sampleOffsetInPoints / sampleWidth)
        if sampleOffset < 0 {
            sampleOffset = 0
        } else if sampleOffset >= CGFloat(sampleCount) {
            sampleOffset = CGFloat(sampleCount - 1)
        }
        return UInt(sampleOffset)
    }

    internal func setup() {
        backgroundColor = UIColor.whiteColor()

        // UIScrollView zoom requires a content subview, because the pianoroll subview would be
        // to large we need to disable the default pinch recognizer and add our own
        if let gestureRecognizers = self.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if let pinchRecognizer = recognizer as? UIPinchGestureRecognizer {
                    pinchRecognizer.enabled = false
                }
            }
        }
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: Selector("handlePinch:"))
        addGestureRecognizer(pinchRecognizer)
    }

    internal func handlePinch(recognizer: UIPinchGestureRecognizer) {
        let scale = recognizer.scale
        if recognizer.state == UIGestureRecognizerState.Began {
            recognizerScaleBegan = scale
            timeScaleBegan = timeScale
        } else if recognizer.state == UIGestureRecognizerState.Changed {
            let delta = NSTimeInterval(recognizerScaleBegan - scale) * timeScaleBegan
            timeScale = timeScaleBegan + delta
        }
    }

    internal override func layoutSubviews() {
        contentInset.top = 0
        contentSize.height = bounds.height
        contentSize.width = bounds.width * CGFloat(timeLength / timeScale)
        setNeedsDisplay()
    }

    override func drawRect(rect: CGRect) {
        if frequencyBinCount == 0 {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()
        let fs = sampleRate / Float(frequencyBinCount)
        let timePoints = sampleCount / frequencyBinCount

        UIColor.whiteColor().setFill()
        CGContextFillRect(context, rect)
        peakColor.setStroke()
        
        var barRect = CGRectZero
        barRect.size.width = sliceWidth

        var yScaling = yForFrequencyMel
        if yScale == .Linear {
            yScaling = yForFrequencyLinear
        }

        for var t = 0; t < Int(timePoints); t += 1 {
            if (barRect.maxX < bounds.minX) {
                barRect.origin.x += barRect.width
                continue
            }

            if (barRect.minX > bounds.maxX) {
                break
            }

            for var fi: Int = 0; fi < frequencyBinCount; fi += 1 {
                let f0 = Float(fi) * fs
                let f1 = Float(fi + 1) * fs

                let minY = yScaling(f1)
                let maxY = yScaling(f0)

                barRect.origin.y = minY
                barRect.size.height = maxY - minY

                let index = fi + t * frequencyBinCount
                let dbValue = 10.0 * log10(samples[index])
                setFillColorForDecibel(dbValue, timeIndex: t)
                CGContextFillRect(context, barRect)

                if peaks != nil && peaks[index] > 0 {
                    CGContextStrokeRect(context, barRect)
                }
            }

            barRect.origin.x += barRect.width
        }
    }

    func yForFrequencyMel(f: Float) -> CGFloat {
        if f < minFrequency {
            return bounds.height
        }
        if f >= maxFrequency {
            return 0
        }

        let minM = 2595.0 * log10(1 + minFrequency/700.0)
        let maxM = 2595.0 * log10(1 + maxFrequency/700.0)
        let m = 2595.0 * log10(1 + f/700.0)
        return bounds.height * (1 - CGFloat(m - minM) / CGFloat(maxM - minM))
    }

    func yForFrequencyLinear(f: Float) -> CGFloat {
        if f < minFrequency {
            return bounds.height
        }
        if f >= maxFrequency {
            return 0
        }
        return bounds.height * (1 - CGFloat(f - minFrequency) / CGFloat(maxFrequency - minFrequency))
    }

    func setFillColorForDecibel(dbValue: Double, timeIndex: Int) {
        var value = (dbValue - decibelGround) / -decibelGround
        if value < 0 {
            value = 0
        }

        let hue = hueMin + (hueMax - hueMin) * CGFloat(value)
        let saturation = saturationMin + (saturationMax - saturationMin) * CGFloat(value)
        var brightness: CGFloat = 0.5
        if timeIndex == highlightTimeIndex {
            brightness = 0.75
        }

        let color = Color(hue: hue, saturation: saturation, brightness: brightness, alpha: 1).UIColor
        color.setFill()
    }
}
