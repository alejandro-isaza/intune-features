//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction

protocol SelectableItem: NSObjectProtocol {
    var color: NSColor { get set }
}

class CollectionViewItem: NSCollectionViewItem {
    static let identifier = "CollectionViewItem"

    @IBOutlet weak var checkBox: NSButton!
    @IBOutlet weak var colorWell: NSColorWell!
    
    var itemSelected: ((Bool) -> ())!
    var colorChanged: (NSColor -> ())!

    @IBAction func checkBoxAction(sender: NSButton) {
        let selected = sender.state == 1
        itemSelected(selected)
    }

    @IBAction func colorAction(sender: NSColorWell) {
        colorChanged(sender.color)
    }
}

class CollectionViewHeader: NSView {
    static let identifier = "CollectionViewHeader"

    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var checkBox: NSButton!

    var selectAllAction: ((Bool) -> ())!

    @IBAction func checkBoxAction(sender: NSButton) {
        let selected = sender.state == 1
        selectAllAction(selected)
    }
}

class CollectionViewDataSource: NSObject, NSCollectionViewDataSource {
    var neuralNet: NeuralNet

    var waveformItem = WaveformItem()
    var labelsItem = LabelsItem()
    var layerItems = [LayerItem]()
    var outputItem = OutputItem()

    var itemSelected: ((CollectionViewItem, Bool) -> ())!
    var colorChanged: ((CollectionViewItem, NSColor) -> ())!
    var sectionSelected: ((Int, Bool) -> ())!
    var selectionStatus: ((NSObject) -> Bool)!

    var numberOfSections: Int {
        return neuralNet.lstmLayers.count + 3
    }

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

    func collectionView(collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> NSView {
        let view = collectionView.makeSupplementaryViewOfKind(kind, withIdentifier: CollectionViewHeader.identifier, forIndexPath: indexPath) as! CollectionViewHeader
        view.selectAllAction = { selected in
            self.sectionSelected(indexPath.section, selected)
        }
        view.label.stringValue = titleForSection(indexPath.section)
        view.layer?.backgroundColor = NSColor.windowBackgroundColor().CGColor
        return view
    }

    func numberOfSectionsInCollectionView(collectionView: NSCollectionView) -> Int {
        return numberOfSections
    }

    func collectionView(collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }

        if section == 1 {
            return labelsItem.timelines.count
        }

        if section == numberOfSections - 1 {
            return outputItem.timelines.count
        }

        let layerIndex = section - 2
        return layerItems[layerIndex].timelines.count
    }

    func collectionView(collectionView: NSCollectionView, itemForRepresentedObjectAtIndexPath indexPath: NSIndexPath) -> NSCollectionViewItem {
        let item = itemForIndex(indexPath.item, inSection: indexPath.section)
        let selected = selectionStatus(item)

        let view = collectionView.makeItemWithIdentifier(CollectionViewItem.identifier, forIndexPath: indexPath) as! CollectionViewItem
        view.representedObject = item
        view.itemSelected = { selected in
            self.itemSelected(view, selected)
        }
        view.colorChanged = { color in
            self.colorChanged(view, color)
        }
        view.checkBox.title = titleForIndex(indexPath.item, inSection: indexPath.section)
        view.checkBox.state = selected ? 1 : 0
        if let selectableItem = item as? SelectableItem {
            view.colorWell.color = selectableItem.color
        }
        return view
    }

    private func titleForSection(section: Int) -> String {
        if section == 0 {
            return "Waveform"
        }

        if section == 1 {
            return "Labels"
        }

        if section == numberOfSections - 1 {
            return "Output"
        }

        let layerIndex = section - 2
        return "Layer \(layerIndex)"
    }

    private func titleForIndex(index: Int, inSection section: Int) -> String {
        if section == 0 {
            return "Waveform"
        }

        if section == 1 {
            let labelItem = labelsItem.timelines[index]
            switch labelItem.type {
            case .Onset:
                return "Onset"
            case .Polyphony:
                return "Polyphony"
            case .Note(let noteNumber):
                let note = Note(midiNoteNumber: noteNumber + Note.representableRange.startIndex)
                return "Note \(note)"
            }
        }

        if section == numberOfSections - 1 {
            return neuralNet.titleForOutputIndex(index)
        }

        return "Layer \(index)"
    }

    private func itemForIndex(index: Int, inSection section: Int) -> NSObject {
        if section == 0 {
            return waveformItem
        }

        if section == 1 {
            return labelsItem.timelines[index]
        }

        if section == numberOfSections - 1 {
            return outputItem.timelines[index]
        }

        let layerIndex = section - 2
        return layerItems[layerIndex].timelines[index]
    }
}

class CollectionViewDelegate: NSObject, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {
    func collectionView(collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> NSSize {
        return NSSize(width: 0, height: 30)
    }
}
