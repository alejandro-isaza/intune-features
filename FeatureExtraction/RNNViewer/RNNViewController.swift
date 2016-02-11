//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import Peak
import PlotKit
import Upsurge

class RNNViewController: NSViewController, NSOutlineViewDelegate {
    let waveformColor = NSColor.blueColor()

    @IBOutlet weak var offsetSlider: NSSlider!
    @IBOutlet weak var offsetTextField: NSTextField!
    @IBOutlet weak var lengthSlider: NSSlider!
    @IBOutlet weak var lengthTextField: NSTextField!

    @IBOutlet weak var outlineView: NSOutlineView!

    var audioFile: AudioFile?
    var offset = 0
    var length = 1.0
    var data = ValueArray<Double>()
    var snapshots = [Snapshot]()

    var neuralNet = try! NeuralNet()
    var dataSource: OutlineViewDataSource!

    override func viewDidLoad() {
        super.viewDidLoad()

        updateView()

        dataSource = OutlineViewDataSource(neuralNet: neuralNet)
        outlineView.setDataSource(dataSource)
        outlineView.setDelegate(self)
        outlineView.reloadData()

        neuralNet.forwardPassAction = { snapshot in
            self.snapshots.append(snapshot)
            if self.snapshots.count == self.neuralNet.processingCount {
                dispatch_async(dispatch_get_main_queue()) {
                    self.outlineView.reloadData()
                }
            }
        }
    }

    func updateView() {
        offsetTextField.integerValue = offset
        offsetSlider.integerValue = offset
        lengthTextField.doubleValue = length
        lengthSlider.doubleValue = length
    }

    func updateOpenPath(path: String?) {
        guard let path = path else {
            return
        }

        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue(path, forKey: "openPath")
        defaults.synchronize()
    }

    func reload() {
        guard let audioFile = audioFile else {
            return
        }

        audioFile.currentFrame = offset

        let sampleCount = Int(length * FeatureBuilder.samplingFrequency)
        if data.capacity < sampleCount {
            data = ValueArray<Double>(capacity: sampleCount)
        }
        withPointer(&data) { pointer in
            data.count = audioFile.readFrames(pointer, count: sampleCount) ?? 0
        }

        snapshots.removeAll()
        neuralNet.processData(data)
    }


    // MARK: Actions

    @IBAction func openDocument(sender: AnyObject?) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["wav", "m4a", "aiff", "mp3"]

        let defaults = NSUserDefaults.standardUserDefaults()
        if let path = defaults.valueForKey("openPath") as? String {
            panel.directoryURL = NSURL(fileURLWithPath: path)
        }

        panel.beginSheetModalForWindow(view.window!, completionHandler: { result in
            if result == NSFileHandlingPanelOKButton {
                let url = panel.URLs.first!
                self.updateOpenPath(panel.directoryURL?.path)
                self.openURL(url)
            }
        })
    }

    func openURL(url: NSURL) {
        guard let path = url.path else {
            return
        }
        guard let audioFile = AudioFile.open(path) else {
            return
        }
        precondition(audioFile.sampleRate == FeatureBuilder.samplingFrequency)
        self.audioFile = audioFile

        let frameCount = Int(audioFile.frameCount)
        offsetSlider.maxValue = Double(frameCount - FeatureBuilder.windowSize)

        offset = 0
        offsetSlider.integerValue = offset
        offsetTextField.integerValue = offset
        
        reload()
    }

    @IBAction func offsetSliderDidChange(sender: AnyObject) {
        offset = offsetSlider.integerValue
        updateView()
        reload()
    }

    @IBAction func offsetTextFieldDidChange(sender: AnyObject) {
        offset = offsetTextField.integerValue
        updateView()
        reload()
    }

    @IBAction func lengthSliderDidChange(sender: AnyObject) {
        length = lengthSlider.doubleValue
        updateView()
        reload()
    }

    @IBAction func lengthTextFieldDidChange(sender: AnyObject) {
        length = lengthTextField.doubleValue
        updateView()
        reload()
    }


    // MARK: NSOutlineViewDelegate

    struct ColumnIdentifiers {
        static let name = "NameColumn"
        static let timeline = "TimelineColumn"
    }

    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        guard let column = tableColumn else {
            return nil
        }

        let reusedView = outlineView.makeViewWithIdentifier(column.identifier, owner: self)

        switch column.identifier {
        case ColumnIdentifiers.name:
            let title: String
            if item is WaveformItem {
                title = "Waveform"
            } else if let layerItem = item as? LayerItem {
                title = "Layer \(layerItem.index)"
            } else if item is OutputItem {
                title = "Output"
            } else if let timelineItem = item as? UnitTimelineItem {
                title = "\(timelineItem.unitIndex)"
            } else if let timelineItem = item as? OutputTimelineItem {
                title = "\(timelineItem.index)"
            } else {
                title = ""
            }
            return createOutlineLabel(title)

        case ColumnIdentifiers.timeline:
            if item is WaveformItem {
                let view = reusedView as? PlotView ?? PlotView()
                updateWaveformPlotView(view)
                return view
            } else if item is UnitTimelineItem || item is OutputTimelineItem {
                let view = reusedView as? PlotView ?? PlotView()
                updatePlotView(view, withItem: item)
                return view
            } else {
                return nil
            }

        default:
            return nil
        }
    }

    func createOutlineLabel(title: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.drawsBackground = false
        textField.bezeled = false
        textField.editable = false
        textField.selectable = false
        textField.refusesFirstResponder = true
        textField.maximumNumberOfLines = 1
        textField.lineBreakMode = NSLineBreakMode.ByTruncatingTail
        textField.stringValue = title
        container.addSubview(textField)

        textField.leadingAnchor.constraintEqualToAnchor(container.leadingAnchor, constant: 8).active = true
        textField.trailingAnchor.constraintEqualToAnchor(container.trailingAnchor).active = true
        textField.topAnchor.constraintEqualToAnchor(container.topAnchor, constant: 1).active = true
        textField.bottomAnchor.constraintEqualToAnchor(container.bottomAnchor).active = true

        return container
    }

    func updateWaveformPlotView(plotView: PlotView) {
        let sampleCount = data.count
        if sampleCount == 0 {
            return
        }
        
        let samplesPerPoint = sampleCount / Int(view.bounds.width)
        let valueCount = sampleCount / samplesPerPoint

        let values = ValueArray<Double>(capacity: valueCount)

        for index in 0.stride(to: sampleCount - samplesPerPoint, by: samplesPerPoint) {
            // Get the RMS value for the current point
            let size = min(samplesPerPoint, sampleCount - index)
            let value = rmsq(data[index..<index+size])
            values.append(value)
        }

        plotView.insets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        plotView.clear()

        let top = PointSet(values: values)
        top.pointType = .None
        top.lineColor = waveformColor
        top.fillColor = waveformColor
        plotView.addPointSet(top)

        let bottom = PointSet(values: -1 * values)
        bottom.pointType = .None
        bottom.lineColor = waveformColor
        bottom.fillColor = waveformColor
        plotView.addPointSet(bottom)
    }

    func updatePlotView(plotView: PlotView, withItem item: AnyObject) {
        plotView.insets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let values: ValueArray<Double>
        if let unitItem = item as? UnitTimelineItem {
            values = valuesForLayerIndex(unitItem.layerIndex, unitIndex: unitItem.unitIndex)
        } else if let outputItem = item as? OutputTimelineItem {
            values = valuesForOutputIndex(outputItem.index)
        } else {
            return
        }

        let pointSet = PointSet(values: values)
        pointSet.pointType = .None
        pointSet.lineColor = NSColor.redColor()
        plotView.clear()
        plotView.addPointSet(pointSet)
    }

    func valuesForLayerIndex(layerIndex: Int, unitIndex: Int) -> ValueArray<Double> {
        let values = ValueArray<Double>(capacity: snapshots.count)
        for snapshot in snapshots {
            let activations = snapshot.activations[layerIndex]
            var value = Double(activations[unitIndex])
            if !isfinite(value) {
                value = 0
            }
            values.append(value)
        }
        return values
    }

    func valuesForOutputIndex(index: Int) -> ValueArray<Double> {
        let values = ValueArray<Double>(capacity: snapshots.count)
        for snapshot in snapshots {
            var value = Double(snapshot.output[index])
            if !isfinite(value) {
                value = 0
            }
            values.append(value)
        }
        return values
    }

    func outlineView(outlineView: NSOutlineView, heightOfRowByItem item: AnyObject) -> CGFloat {
        if item is LayerItem || item is OutputItem {
            return 20
        }

        return 50
    }
}
