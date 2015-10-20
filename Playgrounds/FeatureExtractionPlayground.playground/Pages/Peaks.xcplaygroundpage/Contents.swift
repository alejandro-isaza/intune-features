import FeatureExtraction
import HDF5Kit
import PlotKit
import Upsurge
import XCPlayground

typealias Point = Upsurge.Point<Double>

//: ## Helper functions

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


//: ## Setup

let path = testingFeaturesPath()
let labels = readData(path, datasetName: "label")
let peakFrequencies = readData(path, datasetName: "peak_frequencies")
let peakHeights = readData(path, datasetName: "peak_heights")
let rmsData = readData(path, datasetName: "rms")
let peakCount = PeakLocationsFeature.peakCount

func peaksAtIndex(index: Int) -> ([Point], Double) {
    var maxX = 0.0
    var peaks = [Point]()
    for i in 0..<peakCount {
        let point = Point(
            x: peakFrequencies[index*peakCount + i] * 1000,
            y: peakHeights[index*peakCount + i])
        peaks.append(point)

        if point.x > maxX {
            maxX = point.x
        }
    }
    return (peaks, maxX)
}


let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.fixedXInterval = 0...8000
plot.fixedYInterval = 0...0.3
plot.addAxis(Axis(orientation: .Horizontal))
plot.addAxis(Axis(orientation: .Vertical))
XCPShowView("Peaks", view: plot)


//: Sort the examples by label
let exampleCount = labels.count

var labelIndex = [Int: Int]()
for exampleIndex in 0..<exampleCount {
    labelIndex[Int(labels[exampleIndex])] = exampleIndex
}


//: ## Plot noise peaks
let noiseIndex = labelIndex[0]!
let (peaks, maxX) = peaksAtIndex(noiseIndex)
peaks

plot.clear()

let pointSet = PointSet(points: peaks)
pointSet.lines = false
pointSet.pointType = .Ring(radius: 2)
plot.addPointSet(pointSet)

let rms = rmsData[noiseIndex]
let rmsPointSet = PointSet(points: [Point(x: 0, y: rms), Point(x: maxX, y: rms)])
rmsPointSet.color = NSColor.lightGrayColor()
plot.addPointSet(rmsPointSet)

plot
delay(0.1)


//: ## Plot all notes in sequence
for note in notes {
    let label = noteToLabel(note)
    let exampleIndex = labelIndex[label]!
    let (peaks, maxX) = peaksAtIndex(exampleIndex)

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
