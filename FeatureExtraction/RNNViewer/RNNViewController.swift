//  Copyright © 2016 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import HDF5Kit
import Peak
import PlotKit
import Upsurge

var availableColorIndex = 0
let availableColors = [NSColor.redColor(), NSColor.blueColor(), NSColor.greenColor(), NSColor.purpleColor(), NSColor.cyanColor(), NSColor.darkGrayColor(), NSColor.yellowColor(), NSColor.magentaColor(), NSColor.orangeColor(), NSColor.brownColor()]

func nextColor() -> NSColor {
    let color = availableColors[availableColorIndex]
    availableColorIndex = (availableColorIndex + 1) % availableColors.count
    return color
}

class RNNViewController: NSViewController {
    private struct Keys {
        static let openDirectory = "openDirectory"
        static let openPath = "openPath"
    }

    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var offsetSlider: NSSlider!
    @IBOutlet weak var offsetTextField: NSTextField!
    @IBOutlet weak var lengthSlider: NSSlider!
    @IBOutlet weak var lengthTextField: NSTextField!
    @IBOutlet weak var combinedPlotView: PlotView!
    
    var audioFile: AudioFile?
    var labelsFile: File?
    var offset = 0
    var length = 1.0
    var data = ValueArray<Double>()
    var snapshots = [Snapshot]()

    var selectedItems = Set<NSObject>()

    var neuralNet = try! NeuralNet()

    var collectionViewDataSource: CollectionViewDataSource!
    var collectionViewDelegate: CollectionViewDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()

        updateView()

        combinedPlotView.addAxis(Axis(orientation: .Horizontal, ticks: .Fit(5)))
        combinedPlotView.addAxis(Axis(orientation: .Vertical, ticks: .Distance(0.1)))

        neuralNet.forwardPassAction = { snapshot in
            self.snapshots.append(snapshot)
            if self.snapshots.count == self.neuralNet.processingCount {
                dispatch_async(dispatch_get_main_queue()) {
                    self.collectionView.reloadData()
                    self.updateCombinedPlotView()
                }
            }
        }

        collectionViewDelegate = CollectionViewDelegate()
        collectionViewDataSource = CollectionViewDataSource(neuralNet: neuralNet)
        collectionViewDataSource.itemSelected = { item, selected in
            if selected {
                self.selectItem(item)
            } else {
                self.deselectItem(item)
            }
            self.updateCombinedPlotView()
        }
        collectionViewDataSource.colorChanged = { item, color in
            self.setColor(color, forItem: item)
            self.updateCombinedPlotView()
        }
        collectionViewDataSource.sectionSelected = { index, selected in
            if selected {
                self.selectSection(index)
            } else {
                self.deselectSection(index)
            }
        }
        collectionViewDataSource.selectionStatus = { item in
            let selected = self.selectedItems.contains(item)
            return selected
        }
        collectionView.registerNib(NSNib(nibNamed: CollectionViewItem.identifier, bundle: nil)!, forItemWithIdentifier: CollectionViewItem.identifier)
        collectionView.dataSource = collectionViewDataSource
        collectionView.delegate = collectionViewDelegate

        let item = collectionViewDataSource.waveformItem
        selectedItems.insert(item)

        if let path = NSUserDefaults.standardUserDefaults().valueForKey(Keys.openPath) as? String {
            let url = NSURL(string: path)
            openURL(url)
        }
    }

    func setColor(color: NSColor, forItem item: CollectionViewItem) {
        guard let dataItem = item.representedObject as? SelectableItem else {
            return
        }
        dataItem.color = color
        item.colorWell.color = color
    }

    func selectSection(section: Int) {
        let itemCount = collectionView.numberOfItemsInSection(section)
        for i in 0..<itemCount {
            let indexPath = NSIndexPath(forItem: i, inSection: section)
            let item = collectionView.itemAtIndexPath(indexPath) as! CollectionViewItem
            selectItem(item)
        }
        self.updateCombinedPlotView()
    }

    func selectItem(item: CollectionViewItem) {
        guard let dataItem = item.representedObject as? NSObject else {
            return
        }
        selectedItems.insert(dataItem)
        item.checkBox.state = NSOnState
    }

    func deselectSection(section: Int) {
        let itemCount = collectionView.numberOfItemsInSection(section)
        for i in 0..<itemCount {
            let indexPath = NSIndexPath(forItem: i, inSection: section)
            let item = collectionView.itemAtIndexPath(indexPath) as! CollectionViewItem
            deselectItem(item)
        }
        self.updateCombinedPlotView()
    }

    func deselectItem(item: CollectionViewItem) {
        guard let dataItem = item.representedObject as? NSObject else {
            return
        }
        selectedItems.remove(dataItem)
        item.checkBox.state = NSOffState
    }

    func updateView() {
        offsetTextField.integerValue = offset
        offsetSlider.integerValue = offset
        lengthTextField.doubleValue = length
        lengthSlider.doubleValue = length
    }

    func savePath(path: String?) {
        guard let path = path else { return }
        let nsPath = NSString(string: path)
        let directory = nsPath.stringByDeletingLastPathComponent

        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue(directory, forKey: Keys.openDirectory)
        defaults.setValue(path, forKey: Keys.openPath)
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

        if let path = NSUserDefaults.standardUserDefaults().valueForKey(Keys.openDirectory) as? String {
            panel.directoryURL = NSURL(fileURLWithPath: path)
        }

        panel.beginSheetModalForWindow(view.window!, completionHandler: { result in
            if result == NSFileHandlingPanelOKButton {
                let url = panel.URLs.first
                self.savePath(url?.path)
                self.openURL(url)
            }
        })
    }

    func openURL(url: NSURL?) {
        guard let path = url?.path else {
            return
        }
        guard let audioFile = AudioFile.open(path) else {
            return
        }
        precondition(audioFile.sampleRate == FeatureBuilder.samplingFrequency)
        self.audioFile = audioFile

        labelsFile = File.open(path.stringByReplacingExtensionWith("h5"), mode: .ReadOnly)

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

    func updateWaveformPlotView(plotView: PlotView, withColor color: NSColor) {
        let sampleCount = data.count
        if sampleCount == 0 {
            return
        }
        
        let samplesPerPoint = 256
        let valueCount = sampleCount / samplesPerPoint

        var pointsTop = Array<PlotKit.Point>()
        pointsTop.reserveCapacity(valueCount)

        var pointsBottom = Array<PlotKit.Point>()
        pointsBottom.reserveCapacity(valueCount)

        let start = FeatureBuilder.windowSize/2 - FeatureBuilder.stepSize
        let stepsInWindow = Double(FeatureBuilder.windowSize) / Double(FeatureBuilder.stepSize)
        for index in start.stride(to: sampleCount - samplesPerPoint, by: samplesPerPoint) {
            // Get the RMS value for the current point
            let size = min(samplesPerPoint, sampleCount - index)
            let y = rmsq(data[index..<index+size])
            let x = Double(index) / Double(FeatureBuilder.stepSize) - (stepsInWindow - 1) / 2
            pointsTop.append(PlotKit.Point(x: x, y: y))
            pointsBottom.append(PlotKit.Point(x: x, y: -y))
        }

        let top = PointSet(points: pointsTop)
        top.pointType = .None
        top.lineColor = color
        top.fillColor = color
        plotView.addPointSet(top)

        let bottom = PointSet(points: pointsBottom)
        bottom.pointType = .None
        bottom.lineColor = color
        bottom.fillColor = color
        plotView.addPointSet(bottom)
    }

    func updateLabelsPlotView(plotView: PlotView, withItem item: LabelTimelineItem, withColor color: NSColor) {
        let featureOffset = max(0, offset / FeatureBuilder.stepSize - 1)
        let sampleCount = Int(length * FeatureBuilder.samplingFrequency)
        let featureCount = FeatureBuilder.windowCountInSamples(sampleCount)

        var values = ValueArray<Double>()
        switch item.type {
        case .Onset:
            if let dataset = labelsFile?.openDoubleDataset(Table.labelsOnset.rawValue) {
                values = ValueArray(dataset[featureOffset..<featureOffset + featureCount])
            }

        case .Polyphony:
            if let dataset = labelsFile?.openDoubleDataset(Table.labelsPolyphony.rawValue) {
                values = ValueArray(dataset[featureOffset..<featureOffset + featureCount])
            }

        case .Note(let noteNumber):
            if let dataset = labelsFile?.openDoubleDataset(Table.labelsNotes.rawValue) {
                values = ValueArray(dataset[featureOffset..<featureOffset + featureCount, noteNumber])
            }
        }

        let pointSet = PointSet(values: values)
        pointSet.pointType = .None
        pointSet.lineColor = color
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

    func updateCombinedPlotView() {
        combinedPlotView.removeAllPlots()
        selectedItems.forEach { item in
            if let selectableItem = item as? SelectableItem {
                addItemToCombinedPlotView(item, withColor: selectableItem.color)
            }
        }
    }

    func addItemToCombinedPlotView(item: AnyObject, withColor color: NSColor) {
        var values = ValueArray<Double>()
        if item is WaveformItem {
            updateWaveformPlotView(combinedPlotView, withColor: color)
            return
        } else if let labelItem = item as? LabelTimelineItem {
            updateLabelsPlotView(combinedPlotView, withItem: labelItem, withColor: color)
        } else if let unitItem = item as? UnitTimelineItem {
            values = valuesForLayerIndex(unitItem.layerIndex, unitIndex: unitItem.unitIndex)
        } else if let outputItem = item as? OutputTimelineItem {
            values = valuesForOutputIndex(outputItem.index)
        } else {
            return
        }

        let pointSet = PointSet(values: values)
        pointSet.pointType = .None
        pointSet.lineColor = color
        combinedPlotView.addPointSet(pointSet)
    }
}
