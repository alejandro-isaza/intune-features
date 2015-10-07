import AudioKit
import FeatureExtraction
import HDF5
import PlotKit
import Surge
import XCPlayground

typealias Point = Surge.Point<Double>
let plotSize = NSSize(width: 1024, height: 400)

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

guard let path = NSBundle.mainBundle().pathForResource("testing", ofType: "h5") else {
    fatalError("File not found")
}
let labels = readData(path, datasetName: "label")
let featureData = readData(path, datasetName: "data")



let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.fixedYInterval = 0...0.3
plot.addAxis(Axis(orientation: .Horizontal))
plot.addAxis(Axis(orientation: .Vertical))
XCPShowView("Bands", view: plot)


let exampleCount = labels.count
let exampleSize = RMSFeature.size() + PeakLocationsFeature.size() + PeakHeightsFeature.size() + BandsFeature.size()
let peakCount = PeakLocationsFeature.peakCount
let bandCount = BandsFeature.size()

var noteIndex = [Int: Int]()
for exampleIndex in 0..<exampleCount {
    let note = Int(labels[exampleIndex] + 24)
    noteIndex[note] = exampleIndex
}

for note in 36...96 {
    let exampleIndex = noteIndex[note]!
    var exampleStart = exampleSize * exampleIndex
    let locationsRange = exampleStart..<exampleStart+peakCount
    let heightsRange = locationsRange.endIndex..<locationsRange.endIndex+peakCount
    let bandsRange = heightsRange.endIndex..<heightsRange.endIndex+bandCount

    plot.clear()

    let pointSet = PointSet(values: [Double](featureData[bandsRange]))
    plot.addPointSet(pointSet)

    let expectedBand = Double(note - 24 + 1)
    let expectedPointSet = PointSet(points: [Point(x: expectedBand, y: 0), Point(x: expectedBand, y: 1)])
    expectedPointSet.color = NSColor.lightGrayColor()
    plot.addPointSet(expectedPointSet)

    NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1))
}
