//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import BrainCore
import FeatureExtraction

class LabelsItem: NSObject {
    var timelines = [LabelTimelineItem]()
}

class LabelTimelineItem: NSObject, SelectableItem {
    enum Type {
        case Onset
        case Polyphony
        case Note(Int)
    }

    var type: Type
    var color: NSColor
    var title: String
    var shortTitle: String

    init(type: Type) {
        self.type = type
        switch type {
        case .Onset:
            color = NSColor.blackColor()
            title = "Onset Label"
            shortTitle = "Onset"
        case .Polyphony:
            color = NSColor.darkGrayColor()
            title = "Polyphony Label"
            shortTitle = "Polyphony"
        case .Note(let number):
            let note = Note(midiNoteNumber: number + Note.representableRange.startIndex)
            color = note.color
            title = "\(note.description) Label"
            shortTitle = note.description
        }
    }


    // MARK: NSObject

    override func isEqual(object: AnyObject?) -> Bool {
        guard let rhs = object as? LabelTimelineItem else {
            return false
        }
        switch (self.type, rhs.type) {
        case (.Onset, .Onset): return true
        case (.Polyphony, .Polyphony): return true
        case (.Note(let a), .Note(let b)) where a == b: return true
        default: return false
        }
    }

    override var hashValue: Int {
        switch type {
        case .Onset: return 0.hashValue
        case .Polyphony: return 1.hashValue
        case .Note(let noteNumber): return (2 + noteNumber).hashValue
        }
    }
}
