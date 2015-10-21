import FeatureExtraction
import HDF5Kit
import PlotKit
import Upsurge
import XCPlayground

typealias Point = Upsurge.Point<Double>

//: ## Parameters
//: Start by selecting the feature and example
let featureName = "bands"
let exampleIndex = 51

//: ## Setup code
//: No need to touch this
func readData(filePath: String, datasetName: String) -> [Double] {
    guard let file = File.open(filePath, mode: .ReadOnly) else {
        fatalError("Failed to open file")
    }

    guard let dataset = Dataset.open(file: file, name: datasetName) else {
        fatalError("Failed to open Dataset")
    }

    let size = Int(dataset.space.size)
    var data = [Double](count: size, repeatedValue: 0.0)
    dataset.readDouble(&data)

    return data
}

let path = testingFeaturesPath()
let labels = readData(path, datasetName: "label")
let featureData = readData(path, datasetName: featureName)

let label = labels[exampleIndex]
let note = labelToNote(label)!

//: ## Plotting code
let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.addAxis(Axis(orientation: .Horizontal))
plot.addAxis(Axis(orientation: .Vertical))
XCPShowView(featureName, view: plot)

let exampleCount = labels.count
let exampleSize = featureData.count / exampleCount
let points = (0..<exampleSize).map { featureIndex -> Point in
    let value = featureData[exampleIndex * exampleSize + featureIndex]
    return Point(x: Double(featureIndex), y: value)
}

let pointSet = PointSet(points: points)
plot.addPointSet(pointSet)

let expectedBand0 = Double(note - BandsFeature.notes.startIndex)
let expectedBand1 = freqToNote(noteToFreq(Double(note))*2) - Double(BandsFeature.notes.startIndex)
let expectedBand2 = freqToNote(noteToFreq(Double(note))*3) - Double(BandsFeature.notes.startIndex)
let expectedPointSet = PointSet(points: [
    Point(x: expectedBand0, y: 0), Point(x: expectedBand0, y: 0.1), Point(x: expectedBand0, y: 0),
    Point(x: expectedBand1, y: 0), Point(x: expectedBand1, y: 0.1), Point(x: expectedBand1, y: 0),
    Point(x: expectedBand2, y: 0), Point(x: expectedBand2, y: 0.1), Point(x: expectedBand2, y: 0)
])
expectedPointSet.color = NSColor.lightGrayColor()
plot.addPointSet(expectedPointSet)

plot
