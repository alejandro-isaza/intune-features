import FeatureExtraction
import HDF5Kit
import PlotKit
import Upsurge
import XCPlayground

let notes = 36...96
let bandNotes = 24...120
let bandSize = 1.0

public func noteForLabel(label: Double) -> Int {
    return Int(label) - 1 + notes.startIndex
}

public func bandForNote(note: Double) -> Int {
    return Int(round((note - Double(bandNotes.startIndex)) / bandSize))
}

public func noteForBand(band: Int) -> Double {
    return Double(bandNotes.startIndex) + Double(band) * bandSize
}

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

let label = 53
let note = noteForLabel(Double(label))
let band = bandForNote(Double(note))

let path = testingFeaturesPath()
let labels = readData(path, datasetName: "label")
let featureData = readData(path, datasetName: "peak_heights")


let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.fixedYInterval = 0...0.1
plot.addAxis(Axis(orientation: .Horizontal))
plot.addAxis(Axis(orientation: .Vertical))
XCPlaygroundPage.currentPage.liveView = plot


let exampleCount = labels.count
let bandCount = bandNotes.count
var startIndices = [Int]()

for exampleIndex in 0..<exampleCount {
    var exampleStart = bandCount * exampleIndex
    if Int(labels[exampleIndex]) == label {
        startIndices.append(bandCount * exampleIndex)
    }
}

for exampleStart in startIndices {
    plot.clear()

    let points = (0..<bandCount).map{ band in
        Point(x: noteForBand(band), y: featureData[exampleStart + band])
    }
    let pointSet = PointSet(points: points)
    plot.addPointSet(pointSet)

    let expectedNote = noteForBand(band)
    let expectedPointSet = PointSet(points: [
        Point(x: expectedNote, y: 0), Point(x: expectedNote, y: 1), Point(x: expectedNote, y: 0),
        Point(x: expectedNote + 12, y: 0), Point(x: expectedNote + 12, y: 1), Point(x: expectedNote + 12, y: 0)
    ])
    expectedPointSet.color = NSColor.lightGrayColor()
    plot.addPointSet(expectedPointSet)

    plot
    delay(0.1)
}
