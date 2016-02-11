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

class OutlineViewDataSource: NSObject, NSOutlineViewDataSource {
    var neuralNet: NeuralNet

    var layerItems = [LayerItem]()
    var outputItem = OutputItem()

    init(neuralNet: NeuralNet) {
        self.neuralNet = neuralNet

        for (layerIndex, layer) in neuralNet.lstmLayers.enumerate() {
            let item = LayerItem(index: layerIndex)
            layerItems.append(item)

            for unitIndex in 0..<Int(layer.parameters.unitCount) {
                let timelineItem = UnitTimelineItem(layerIndex: layerIndex, unitIndex: unitIndex)
                item.timelines.append(timelineItem)
            }
        }

        for index in 0..<neuralNet.outputSize {
            let item = OutputTimelineItem(resultIndex: index)
            outputItem.timelines.append(item)
        }
    }

    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if item == nil {
            return neuralNet.lstmLayers.count + 1
        } else if let layerItem = item as? LayerItem {
            return layerItem.timelines.count
        } else if let outputItem = item as? OutputItem {
            return outputItem.timelines.count
        }
        return 0
    }

    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if item == nil {
            if index < layerItems.count {
                return layerItems[index]
            } else {
                return outputItem
            }
        } else if let layerItem = item as? LayerItem {
            return layerItem.timelines[index]
        } else if let outputItem = item as? OutputItem {
            return outputItem.timelines[index]
        }

        fatalError("Unknown item \(item)")
    }

    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return item is LayerItem || item is OutputItem
    }
}
