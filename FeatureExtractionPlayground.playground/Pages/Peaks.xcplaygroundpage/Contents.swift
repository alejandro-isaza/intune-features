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
let peakFrequencies = readData(path, datasetName: "peak_frequencies")
let peakHeights = readData(path, datasetName: "peak_heights")
let rmsData = readData(path, datasetName: "rms")


let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.fixedXInterval = 0...8000
plot.fixedYInterval = 0...0.3
plot.addAxis(Axis(orientation: .Horizontal))
plot.addAxis(Axis(orientation: .Vertical))
XCPShowView("Peaks", view: plot)


let exampleCount = labels.count
let peakCount = PeakLocationsFeature.peakCount

var noteIndex = [Int: Int]()
for exampleIndex in 0..<exampleCount {
    if let note = labelToNote(labels[exampleIndex]) {
        noteIndex[note] = exampleIndex
    }
}

for note in notes {
    let exampleIndex = noteIndex[note]!
    var exampleStart = peakCount * exampleIndex

    var maxX = 0.0
    var peaks = [Point]()
    for i in 0..<peakCount {
        let point = Point(
            x: peakFrequencies[exampleStart + i] * 1000,
            y: peakHeights[exampleStart + i])
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

    let rms = rmsData[exampleIndex]
    let rmsPointSet = PointSet(points: [Point(x: 0, y: rms), Point(x: maxX, y: rms)])
    rmsPointSet.color = NSColor.lightGrayColor()
    plot.addPointSet(rmsPointSet)

    let expectedFreq = noteToFreq(Double(note))
    let expectedPointSet = PointSet(points: [Point(x: expectedFreq, y: 0), Point(x: expectedFreq, y: 1)])
    expectedPointSet.color = NSColor.lightGrayColor()
    plot.addPointSet(expectedPointSet)

    plot
    delay(0.1)
}
