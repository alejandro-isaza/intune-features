//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import BrainCore

class LabelsItem: NSObject {
    var timelines = [LabelTimelineItem]()
}

class LabelTimelineItem: NSObject {
    enum Type {
        case Onset
        case Polyphony
        case Note(Int)
    }

    var type: Type

    init(type: Type) {
        self.type = type
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
