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
    let windowSize = 2048
    let stepSize = 1024

    private struct Keys {
        static let openDirectory = "openDirectory"
        static let openPath = "openPath"
    }

    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var offsetSlider: NSSlider!
    @IBOutlet weak var offsetTextField: NSTextField!
    @IBOutlet weak var lengthSlider: NSSlider!
    @IBOutlet weak var lengthTextField: NSTextField!
    @IBOutlet weak var pianoRollView: PianoRollView!
    @IBOutlet weak var combinedPlotView: PlotView!
    
    var audioFile: AudioFile?
    var labelsFile: File?
    var offset = 0
    var length = 1.0
    var data = ValueArray<Double>()
    var labelEvents = [Event]()
    var netEvents = [Event]()
    var snapshots = [Snapshot]()

    var selectedItems = Set<NSObject>()

    var networkOffset = 0
    var networkLastOffset = 0
    var neuralNet: NeuralNet!
    var networkDecoder = NetworkDecoder()

    var collectionViewDataSource: CollectionViewDataSource!
    var collectionViewDelegate: CollectionViewDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()

        neuralNet = try! NeuralNet(windowSize: windowSize, stepSize: stepSize)
        updateView()

        combinedPlotView.addAxis(Axis(orientation: .Horizontal, ticks: .Fit(5)))
        combinedPlotView.addAxis(Axis(orientation: .Vertical, ticks: .Distance(0.1)))

        neuralNet.forwardPassAction = { snapshot in
            let output = snapshot.output
            let count = output.count
            self.networkDecoder.processOutput(output[count - 2], polyphonyValue: output[count - 1], noteValues: output[0..<Note.noteCount])

            self.networkOffset += self.stepSize
            self.snapshots.append(snapshot)
            if self.snapshots.count == self.neuralNet.processingCount {
                dispatch_async(dispatch_get_main_queue()) {
                    self.collectionView.reloadData()
                    self.updateCombinedPlotView()
                    self.updatePianoRollView()
                }
            }
        }
        networkDecoder.eventAction = { notes in
            for i in 0..<self.netEvents.count {
                if self.netEvents[i].duration == 0 {
                    self.netEvents[i].duration = self.networkOffset - self.networkLastOffset
                }
            }
            for note in notes {
                let event = Event(note: note, start: self.networkOffset, duration: 0, velocity: 0.63)
                self.netEvents.append(event)
            }
            self.networkLastOffset = self.networkOffset
        }

        collectionViewDelegate = CollectionViewDelegate()
        collectionViewDataSource = CollectionViewDataSource(neuralNet: neuralNet)
        collectionViewDataSource.objectSelected = { object, selected in
            if selected {
                self.selectedItems.insert(object)
            } else {
                self.selectedItems.remove(object)
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
            let object = collectionViewDataSource.objectAtIndex(i, inSection: section)
            selectedItems.insert(object)
            if let item = collectionView.itemAtIndexPath(NSIndexPath(forItem: i, inSection: section)) as? CollectionViewItem {
                item.checkBox.state = NSOnState
            }
        }
        self.updateCombinedPlotView()
    }

    func deselectSection(section: Int) {
        let itemCount = collectionView.numberOfItemsInSection(section)
        for i in 0..<itemCount {
            let object = collectionViewDataSource.objectAtIndex(i, inSection: section)
            selectedItems.remove(object)
            if let item = collectionView.itemAtIndexPath(NSIndexPath(forItem: i, inSection: section)) as? CollectionViewItem {
                item.checkBox.state = NSOffState
            }
        }
        self.updateCombinedPlotView()
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

        let sampleCount = Int(length * Configuration.samplingFrequency)
        if data.capacity < sampleCount {
            data = ValueArray<Double>(capacity: sampleCount)
        }
        withPointer(&data) { pointer in
            data.count = audioFile.readFrames(pointer, count: sampleCount) ?? 0
        }

        snapshots.removeAll()
        netEvents.removeAll()
        networkOffset = offset
        networkLastOffset = offset
        neuralNet.processData(data)
        updatePianoRollView()
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
        precondition(audioFile.sampleRate == Configuration.samplingFrequency)
        self.audioFile = audioFile

        labelsFile = File.open(path.stringByReplacingExtensionWith("h5"), mode: .ReadOnly)

        let frameCount = Int(audioFile.frameCount)
        offsetSlider.maxValue = Double(frameCount - windowSize)

        offset = 0
        offsetSlider.integerValue = offset
        offsetTextField.integerValue = offset

        loadEvents()
        reload()
    }

    func loadEvents() {
        labelEvents.removeAll()

        guard let labelsFile = labelsFile else {
            return
        }
        guard let startDataset = labelsFile.openIntDataset(Table.eventsStart.rawValue) else {
            return
        }
        guard let durationDataset = labelsFile.openIntDataset(Table.eventsDuration.rawValue) else {
            return
        }
        guard let noteDataset = labelsFile.openIntDataset(Table.eventsNote.rawValue) else {
            return
        }

        let eventCount = startDataset.extent[0]
        labelEvents.reserveCapacity(eventCount)

        for i in 0..<eventCount {
            let note = Note(midiNoteNumber: noteDataset[i].first!)
            let event = Event(note: note, start: startDataset[i].first!, duration: durationDataset[i].first!, velocity: 0.63)
            labelEvents.append(event)
        }
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

        let start = windowSize/2 - stepSize
        let stepsInWindow = Double(windowSize) / Double(stepSize)
        for index in start.stride(to: sampleCount - samplesPerPoint, by: samplesPerPoint) {
            // Get the RMS value for the current point
            let size = min(samplesPerPoint, sampleCount - index)
            let y = rmsq(data[index..<index+size])
            let x = Double(index) / Double(stepSize) - (stepsInWindow - 1) / 2
            pointsTop.append(PlotKit.Point(x: x, y: y))
            pointsBottom.append(PlotKit.Point(x: x, y: -y))
        }

        let top = PointSet(points: pointsTop)
        top.pointType = .None
        top.lineColor = color
        top.fillColor = color
        plotView.addPointSet(top, title: "Waveform")

        let bottom = PointSet(points: pointsBottom)
        bottom.pointType = .None
        bottom.lineColor = color
        bottom.fillColor = color
        plotView.addPointSet(bottom, title: "Waveform")
    }

    func updatePianoRollView() {
        pianoRollView.labelEvents = labelEvents
        pianoRollView.netEvents = netEvents

        let start = offset
        let sampleCount = Int(length * Configuration.samplingFrequency)
        pianoRollView.range = start..<start + sampleCount
    }

    func updateLabelsPlotView(plotView: PlotView, withItem item: LabelTimelineItem, withColor color: NSColor) {
        let featureOffset = max(0, offset / stepSize - 1)
        let sampleCount = Int(length * Configuration.samplingFrequency)
        let featureCount = Configuration.windowCountInSamples(sampleCount, windowSize: windowSize, stepSize: stepSize)

        var values = ValueArray<Double>()
        switch item.type {
        case .Onset:
            if let dataset = labelsFile?.openDoubleDataset(Table.labelsOnset.rawValue) {
                let count = min(featureCount, dataset.space.dims[0] - featureOffset)
                values = ValueArray(dataset[featureOffset..<featureOffset + count])
            }

        case .Polyphony:
            if let dataset = labelsFile?.openDoubleDataset(Table.labelsPolyphony.rawValue) {
                let count = min(featureCount, dataset.space.dims[0] - featureOffset)
                values = ValueArray(dataset[featureOffset..<featureOffset + count])
            }

        case .Note(let noteNumber):
            if let dataset = labelsFile?.openDoubleDataset(Table.labelsNotes.rawValue) {
                let count = min(featureCount, dataset.space.dims[0] - featureOffset)
                values = ValueArray(dataset[featureOffset..<featureOffset + count, noteNumber])
            }
        }

        let pointSet = PointSet(values: values)
        pointSet.pointType = .None
        pointSet.lineColor = color
        plotView.addPointSet(pointSet, title: item.title)
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
        var title = ""
        if item is WaveformItem {
            title = "Waveform"
            updateWaveformPlotView(combinedPlotView, withColor: color)
            return
        } else if let labelItem = item as? LabelTimelineItem {
            title = labelItem.title
            updateLabelsPlotView(combinedPlotView, withItem: labelItem, withColor: color)
        } else if let unitItem = item as? UnitTimelineItem {
            title = unitItem.title
            values = valuesForLayerIndex(unitItem.layerIndex, unitIndex: unitItem.unitIndex)
        } else if let outputItem = item as? OutputTimelineItem {
            title = outputItem.title
            values = valuesForOutputIndex(outputItem.index)
        } else {
            return
        }

        let pointSet = PointSet(values: values)
        pointSet.pointType = .None
        pointSet.lineColor = color
        combinedPlotView.addPointSet(pointSet, title: title)
    }
}
