import AudioKit
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

let path = testingFeatuesPath()
let labels = readData(path, datasetName: "label")
let featureData = readData(path, datasetName: "bands")


let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.fixedYInterval = 0...0.3
plot.addAxis(Axis(orientation: .Horizontal))
plot.addAxis(Axis(orientation: .Vertical))
XCPShowView("Bands", view: plot)


let exampleCount = labels.count
let bandCount = BandsFeature.size()

var noteIndex = [Int: Int]()
for exampleIndex in 0..<exampleCount {
    if let note = labelToNote(labels[exampleIndex]) {
        noteIndex[note] = exampleIndex
    }
}

for note in notes {
    let exampleIndex = noteIndex[note]!
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
