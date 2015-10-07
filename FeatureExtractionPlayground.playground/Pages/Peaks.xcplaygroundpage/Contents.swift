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
plot.fixedXInterval = 0...8000
plot.fixedYInterval = 0...0.3
plot.addAxis(Axis(orientation: .Horizontal))
plot.addAxis(Axis(orientation: .Vertical))
XCPShowView("Peaks", view: plot)


let exampleCount = labels.count
let exampleSize = RMSFeature.size() + PeakLocationsFeature.size() + PeakHeightsFeature.size() + BandsFeature.size()
let peakCount = PeakLocationsFeature.peakCount

var noteIndex = [Int: Int]()
for exampleIndex in 0..<exampleCount {
    let note = Int(labels[exampleIndex] + 24)
    noteIndex[note] = exampleIndex
}

for note in 24...96 {
    let exampleIndex = noteIndex[note]!
    var exampleStart = exampleSize * exampleIndex
    let locationsRange = exampleStart..<exampleStart+peakCount
    let heightsRange = exampleStart+peakCount..<exampleStart+2*peakCount

    var maxX = 0.0
    var peaks = [Point]()
    for i in 0..<peakCount {
        let point = Point(
            x: featureData[locationsRange.startIndex + i] * 1000,
            y: featureData[heightsRange.startIndex + i])
        peaks.append(point)

        if point.x > maxX {
            maxX = point.x
        }
    }

    plot.clear()

    let pointSet = PointSet(points: peaks)
    pointSet.lines = false
    pointSet.pointType = .Ring(radius: 2)
    plot.addPointSet(pointSet)

    let rms = featureData[exampleStart]
    let rmsPointSet = PointSet(points: [Point(x: 0, y: rms), Point(x: maxX, y: rms)])
    rmsPointSet.color = NSColor.lightGrayColor()
    plot.addPointSet(rmsPointSet)

    let expectedFreq = noteToFreq(Double(note))
    let expectedPointSet = PointSet(points: [Point(x: expectedFreq, y: 0), Point(x: expectedFreq, y: 1)])
    expectedPointSet.color = NSColor.lightGrayColor()
    plot.addPointSet(expectedPointSet)

    NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1))
}
