//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

import UIKit

let maximumVisibleNotes: CGFloat = 128

/**
A view controller that displays the given events in a scrollable pianoroll view
*/
public class VMPianoRollViewController: UIViewController {
    @IBOutlet weak var pianoRollContentView: VMPianoRollContentView!
    @IBOutlet weak var visibleNotesSlider: UISlider!

    private var eventRects: Array<NSValue> = []

    class func createWithEventRects(eventRects: Array<NSValue>) -> VMPianoRollViewController {
        let pianoRollViewController = VMPianoRollViewController(nibName: "VMPianoRollViewController", bundle: nil)
        pianoRollViewController.eventRects = eventRects
        return pianoRollViewController
    }

    public override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        pianoRollContentView.eventRects = eventRects

        var bounds = CGRectNull
        for eventRectValue in eventRects {
            var eventRect = eventRectValue.CGRectValue()
            bounds = CGRectUnion(bounds, eventRect)
        }
        visibleNotesSlider.value = Float(bounds.width)
        visibleNotesSlider.minimumValue = Float(bounds.width)
        visibleNotesSlider.maximumValue = Float(maximumVisibleNotes)
    }

    @IBAction private func visibleWidthValueChanged(sender: UISlider) {
        pianoRollContentView.numVisibleNotes = CGFloat(sender.value)
    }
}

internal class VMPianoRollContentView: UIScrollView {
    private var drawingTransform: CGAffineTransform = CGAffineTransformIdentity
    private var drawingTransformScaleY: CGFloat = 5

    // used to convert pinch regocnizer scale into 'zoom'
    private var recognizerBeganScale = CGFloat()
    private var transformBeganScale = CGFloat()

    var noteColor = UIColor.blueColor()
    var eventRects: Array<NSValue> = [] {
        didSet {
            setNeedsLayout()
        }
    }
    var numVisibleNotes: CGFloat = 1 {
        didSet {
            setNeedsLayout()
        }
    }

    required internal init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor.whiteColor()

        // UIScrollView zoom requires a content subview, because the pianoroll subview would be
        // to large we need to disable the default pinch recognizer and add our own
        if let _gestureRecognizers = self.gestureRecognizers {
            for recognizer in _gestureRecognizers {
                if let pinchRecognizer = recognizer as? UIPinchGestureRecognizer {
                    pinchRecognizer.enabled = false
                }
            }
        }
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: Selector("handlePinch:"))
        addGestureRecognizer(pinchRecognizer)
    }

    private func eventsBounds() -> CGRect {
        var bounds = CGRectNull
        for eventRectValue in eventRects {
            var eventRect = eventRectValue.CGRectValue()
            bounds = CGRectUnion(bounds, eventRect)
        }
        if CGRectIsNull(bounds) {
            return CGRectZero
        }

        let padding = maximumVisibleNotes - numVisibleNotes
        var left = padding/2
        var right = padding - left

        var minX = max(0, bounds.minX - left)
        var maxX = min(maximumVisibleNotes, bounds.maxX + right)

        bounds.origin.x = CGFloat(minX)
        bounds.size.width = CGFloat(maxX - minX)
        return bounds
    }

    internal func handlePinch(recognizer: UIPinchGestureRecognizer) {
        let scale = recognizer.scale
        if recognizer.state == UIGestureRecognizerState.Began {
            recognizerBeganScale = scale
            transformBeganScale = drawingTransformScaleY
        } else if recognizer.state == UIGestureRecognizerState.Changed {
            let delta = (scale - recognizerBeganScale) * 4
            drawingTransformScaleY = transformBeganScale + delta
            if drawingTransformScaleY < 1 {
                drawingTransformScaleY = 1
            }
            setNeedsLayout()
        }
    }

    internal override func layoutSubviews() {
        var contentBounds = eventsBounds()
        drawingTransform = CGAffineTransformMakeScale(bounds.size.width / contentBounds.size.width, drawingTransformScaleY)
        contentBounds = CGRectApplyAffineTransform(contentBounds, drawingTransform)
        contentSize = contentBounds.size
        contentInset.left = -contentBounds.origin.x
        scrollIndicatorInsets.left = -contentBounds.origin.x
        setNeedsDisplay()
    }

    internal override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        backgroundColor?.setFill()
        CGContextFillRect(context, rect)
        drawOctaves(context, rect: rect)
        drawEvents(context, rect: rect)
    }

    internal func drawEvents(context: CGContext, rect: CGRect) {
        noteColor.setFill()
        for eventRectValue in eventRects {
            let eventRect = CGRectApplyAffineTransform(eventRectValue.CGRectValue(), drawingTransform)
            if eventRect.intersects(rect) {
                CGContextFillRect(context, eventRect)
            }
        }
    }

    internal func drawOctaves(context: CGContext, rect: CGRect) {
        noteColor.setFill()

        let notesPerOctave = 12
        for var noteIndex = 0; noteIndex < Int(rect.width); noteIndex += notesPerOctave {

        }
    }

}
