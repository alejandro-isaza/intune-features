import FeatureExtraction
import HDF5Kit
import PlotKit
import Upsurge
import XCPlayground

//: ## Parameters
//: Start by selecting the feature and example
let featureName = "bands"
let exampleIndex = 1501
let predictedLabel = 13

//: ## Read the feature data from the HDF5 file
let path = testingFeaturesPath()
guard let file = File.open(path, mode: .ReadOnly) else {
    fatalError("Failed to open file")
}

//: Read the label
let labelDataset = file.openDataset("label")!
var labels = [Int](count: Int(labelDataset.space.size), repeatedValue: 0)
labelDataset.readInt(&labels)
let label = labels[exampleIndex]

//: Read the file offset
let offsetDataset = file.openDataset("offset")!
var offsets = [Int](count: Int(offsetDataset.space.size), repeatedValue: 0)
offsetDataset.readInt(&offsets)
let offset = offsets[exampleIndex]

//: Read the file name
let fileNameDataset = file.openDataset("fileName")!
var fileNames = fileNameDataset.readString()!
let fileName = fileNames[exampleIndex]

//: Read the feature data
let featureDataset = file.openDataset(featureName)!
var featureData = [Double](count: Int(featureDataset.space.size), repeatedValue: 0.0)
featureDataset.readDouble(&featureData)


//: ## Plotting code
let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
plot.addAxis(Axis(orientation: .Vertical))
XCPlaygroundPage.currentPage.liveView = plot

var maxY = 0.0
let exampleCount = labels.count
let exampleSize = featureData.count / exampleCount
let points = (0..<exampleSize).map { featureIndex -> PlotKit.Point in
    let value = featureData[exampleIndex * exampleSize + featureIndex]
    if value > maxY {
        maxY = value
    }
    return PlotKit.Point(x: Double(35 + featureIndex), y: value)
}

let pointSet = PointSet(points: points)
plot.addPointSet(pointSet)

if let note = labelToNote(Double(label)) {
    let expectedBand0 = freqToNote(noteToFreq(Double(note)))
    let expectedBand1 = freqToNote(noteToFreq(Double(note)) * 2)
    let expectedBand2 = freqToNote(noteToFreq(Double(note)) * 3)
    let expectedPointSet = PointSet(points: [
        Point(x: expectedBand0, y: 0), Point(x: expectedBand0, y: maxY), Point(x: expectedBand0, y: 0),
        Point(x: expectedBand1, y: 0), Point(x: expectedBand1, y: maxY), Point(x: expectedBand1, y: 0),
        Point(x: expectedBand2, y: 0), Point(x: expectedBand2, y: maxY), Point(x: expectedBand2, y: 0)
    ])
    expectedPointSet.color = NSColor.orangeColor()
    plot.addPointSet(expectedPointSet)
}

if let note = labelToNote(Double(predictedLabel)) {
    let expectedBand0 = freqToNote(noteToFreq(Double(note)))
    let expectedBand1 = freqToNote(noteToFreq(Double(note)) * 2)
    let expectedBand2 = freqToNote(noteToFreq(Double(note)) * 3)
    let expectedPointSet = PointSet(points: [
        Point(x: expectedBand0, y: 0), Point(x: expectedBand0, y: maxY), Point(x: expectedBand0, y: 0),
        Point(x: expectedBand1, y: 0), Point(x: expectedBand1, y: maxY), Point(x: expectedBand1, y: 0),
        Point(x: expectedBand2, y: 0), Point(x: expectedBand2, y: maxY), Point(x: expectedBand2, y: 0)
        ])
    expectedPointSet.color = NSColor.purpleColor()
    plot.addPointSet(expectedPointSet)
}

plot
XCPlaygroundPage.currentPage.finishExecution()
