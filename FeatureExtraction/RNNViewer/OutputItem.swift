//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import BrainCore

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

class OutputTimelineItem: NSObject {
    var index: Int

    init(resultIndex: Int) {
        self.index = resultIndex
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
