import FeatureExtraction
import HDF5
import PlotKit
import Surge
import XCPlayground

typealias Point = Surge.Point<Double>

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
let featureData = readData(path, datasetName: "bands")


let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.fixedYInterval = 0...0.3
plot.addAxis(Axis(orientation: .Horizontal))
plot.addAxis(Axis(orientation: .Vertical))
XCPShowView("Bands", view: plot)


let exampleCount = labels.count
let bandCount = BandsFeature.size()

var labelIndex = [Int: Int]()
for exampleIndex in 0..<exampleCount {
    labelIndex[Int(labels[exampleIndex])] = exampleIndex
}

let noiseIndex = labelIndex[0]!
let noiseStart = bandCount * noiseIndex
let noiseBands = [Double](featureData[noiseStart..<noiseStart+bandCount])
noiseBands

let pointSet = PointSet(values: noiseBands)
plot.clear()
plot.addPointSet(pointSet)
plot
delay(0.1)

for note in notes {
    let label = noteToLabel(note)
    let exampleIndex = labelIndex[label]!
    var exampleStart = bandCount * exampleIndex

    plot.clear()

    let pointSet = PointSet(values: [Double](featureData[exampleStart..<exampleStart+bandCount]))
    plot.addPointSet(pointSet)

    let expectedBand = Double(note - BandsFeature.notes.startIndex)
    let expectedPointSet = PointSet(points: [Point(x: expectedBand, y: 0), Point(x: expectedBand, y: 1)])
    expectedPointSet.color = NSColor.lightGrayColor()
    plot.addPointSet(expectedPointSet)

    plot
    delay(0.1)
}
