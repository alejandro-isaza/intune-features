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



let locationsPlot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
locationsPlot.fixedXInterval = 0...8000
locationsPlot.fixedYInterval = 0...0.3
locationsPlot.addAxis(Axis(orientation: .Horizontal))
locationsPlot.addAxis(Axis(orientation: .Vertical))


let exampleCount = labels.count
let exampleSize = RMSFeature.size() + PeakLocationsFeature.size() + PeakHeightsFeature.size() + BandsFeature.size()

for exampleIndex in 0..<73 {
    let note = labels[exampleIndex] + 24
    var exampleStart = exampleSize * exampleIndex
    let peakCount = PeakLocationsFeature.peakCount
    let locationsRange = exampleStart..<exampleStart+peakCount
    let heightsRange = exampleStart+peakCount..<exampleStart+2*peakCount

    let rms = featureData[exampleStart]

    var peaks = [Point]()
    for i in 0..<peakCount {
        peaks.append(Point(
            x: featureData[locationsRange.startIndex + i] * 1000,
            y: featureData[heightsRange.startIndex + i]))
    }

    let locationsPointSet = PointSet(points: peaks)
    locationsPointSet.lines = false
    locationsPointSet.pointType = .Ring(radius: 2)
    locationsPointSet.color = NSColor(calibratedHue: CGFloat(exampleIndex)/CGFloat(73), saturation: 1, brightness: 1, alpha: 1)
    locationsPlot.addPointSet(locationsPointSet)
}
XCPShowView("Locations", view: locationsPlot)
