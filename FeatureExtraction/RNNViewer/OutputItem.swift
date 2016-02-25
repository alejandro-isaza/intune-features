//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import BrainCore
import FeatureExtraction

class OutputItem: NSObject {
    var timelines = [OutputTimelineItem]()

    // MARK: NSObject

    override func isEqual(object: AnyObject?) -> Bool {
        guard let _ = object as? OutputItem else {
            return false
        }
        return true
    }

    override var hashValue: Int {
        return 0.hashValue
    }
}

class OutputTimelineItem: NSObject, SelectableItem {
    var index: Int
    var color: NSColor
    var title: String
    var shortTitle: String

    init(resultIndex: Int, title: String, shortTitle: String) {
        self.index = resultIndex
        self.title = title
        self.shortTitle = shortTitle
        if resultIndex < Note.noteCount {
            color = Note(midiNoteNumber: resultIndex + Note.representableRange.startIndex).color
        } else {
            color = NSColor.blackColor()
        }
    }


    // MARK: NSObject

    override func isEqual(object: AnyObject?) -> Bool {
        guard let rhs = object as? OutputTimelineItem else {
            return false
        }
        return index == rhs.index
    }

    override var hashValue: Int {
        return index.hashValue
    }
}
