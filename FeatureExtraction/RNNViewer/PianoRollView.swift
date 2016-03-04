//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction

class PianoRollView: NSView {
    var configuration: Configuration!
    let labelColor = NSColor.blueColor()
    let netColor = NSColor.redColor()

    // Range to display in samples
    var range = 0...0 {
        didSet { needsDisplay = true }
    }

    var labelEvents = [Event]() {
        didSet { needsDisplay = true }
    }

    var netEvents = [Event]() {
        didSet { needsDisplay = true }
    }

    private var noteLineWidth = CGFloat(1)
    private var sampleWidth = CGFloat(1)

    var valueView: NSTextField

    override init(frame: NSRect) {
        valueView = NSTextField()
        super.init(frame: frame)
        setupValueView()
    }

    required init?(coder: NSCoder) {
        valueView = NSTextField()
        super.init(coder: coder)
        setupValueView()
    }

    func setupValueView() {
        valueView.textColor = NSColor.whiteColor()
        valueView.backgroundColor = NSColor.blackColor()
        valueView.editable = false
        valueView.bordered = false
        valueView.selectable = false
        valueView.hidden = true
        addSubview(valueView)
    }
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        noteLineWidth = bounds.height / CGFloat(configuration.representableNoteRange.count)
        sampleWidth = bounds.width / CGFloat(range.count)

        labelColor.setFill()
        for event in labelEvents {
            let rect = eventRect(event)
            NSRectFill(rect)
        }

        netColor.setFill()
        for event in netEvents {
            let rect = eventRect(event)
            NSRectFillUsingOperation(rect, .CompositeDifference)
        }
    }

    private func eventRect(event: Event) -> NSRect {
        let x = CGFloat(event.start - range.startIndex) * sampleWidth
        let width = CGFloat(event.duration) * sampleWidth
        let y = CGFloat(event.note.midiNoteNumber - configuration.representableNoteRange.startIndex) * noteLineWidth
        return NSRect(x: x, y: y, width: width, height: noteLineWidth)
    }

    // MARK: - Mouse handling

    override func updateTrackingAreas() {
        var options = NSTrackingAreaOptions()
        options.unionInPlace(.ActiveInActiveApp)
        options.unionInPlace(.MouseEnteredAndExited)
        options.unionInPlace(.MouseMoved)
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(event: NSEvent) {
        let location = convertPoint(event.locationInWindow, fromView: nil)

        let index = Int(round(location.y / noteLineWidth))
        if index < 0 || index >= configuration?.representableNoteRange.count {
            valueView.hidden = true
            return
        }
        
        let note = Note(midiNoteNumber: index + configuration.representableNoteRange.startIndex)

        valueView.stringValue = note.description
        valueView.hidden = false
        valueView.sizeToFit()
        var frame = valueView.frame
        frame.origin.x = location.x - frame.width/2
        frame.origin.y = location.y + 4
        valueView.frame = frame
    }

    override func mouseExited(event: NSEvent) {
        valueView.hidden = true
    }

}
