//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import BrainCore
import FeatureExtraction

class WaveformItem: NSObject {
}

class OutlineViewDataSource: NSObject, NSOutlineViewDataSource {
    var neuralNet: NeuralNet

    var waveformItem = WaveformItem()
    var labelsItem = LabelsItem()
    var layerItems = [LayerItem]()
    var outputItem = OutputItem()

    init(neuralNet: NeuralNet) {
        self.neuralNet = neuralNet

        labelsItem.timelines.append(LabelTimelineItem(type: .Onset))
        labelsItem.timelines.append(LabelTimelineItem(type: .Polyphony))
        for i in 0..<Note.noteCount {
            labelsItem.timelines.append(LabelTimelineItem(type: .Note(i)))
        }

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
            return neuralNet.lstmLayers.count + 3
        } else if item is LabelsItem {
            return labelsItem.timelines.count
        } else if let layerItem = item as? LayerItem {
            return layerItem.timelines.count
        } else if let outputItem = item as? OutputItem {
            return outputItem.timelines.count
        }
        return 0
    }

    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if item == nil {
            if index == 0 {
                return waveformItem
            } else if index == 1 {
                return labelsItem
            } else if index - 2 < layerItems.count {
                return layerItems[index - 2]
            } else {
                return outputItem
            }
        } else if let labelsItem = item as? LabelsItem {
            return labelsItem.timelines[index]
        } else if let layerItem = item as? LayerItem {
            return layerItem.timelines[index]
        } else if let outputItem = item as? OutputItem {
            return outputItem.timelines[index]
        }

        fatalError("Unknown item \(item)")
    }

    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return item is LayerItem || item is LabelsItem || item is OutputItem
    }
}
