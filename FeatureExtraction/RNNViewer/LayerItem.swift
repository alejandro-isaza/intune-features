//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import BrainCore

class LayerItem: NSObject {
    var index: Int
    var timelines = [UnitTimelineItem]()

    init(index: Int) {
        self.index = index
    }


    // MARK: NSObject

    override func isEqual(object: AnyObject?) -> Bool {
        guard let rhs = object as? LayerItem else {
            return false
        }
        return index == rhs.index
    }

    override var hashValue: Int {
        return index.hashValue
    }
}

class UnitTimelineItem: NSObject {
    var layerIndex: Int
    var unitIndex: Int

    init (layerIndex: Int, unitIndex: Int) {
        self.layerIndex = layerIndex
        self.unitIndex = unitIndex
    }


    // MARK: NSObject

    override func isEqual(object: AnyObject?) -> Bool {
        guard let rhs = object as? UnitTimelineItem else {
            return false
        }
        return layerIndex == rhs.layerIndex && unitIndex == rhs.unitIndex
    }

    override var hashValue: Int {
        return layerIndex.hashValue ^ unitIndex.hashValue
    }
}
