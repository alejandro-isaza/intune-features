import FeatureExtraction
import HDF5Kit
import PlotKit
import Upsurge
import XCPlayground

//: ## Parameters
//: Start by selecting the feature and note you want to analyze
let featureName = "bands"
let featureIndex = 28


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

let path = trainingFeaturesPath()
let labels = readData(path, datasetName: "label")
let featureData = readData(path, datasetName: featureName)

//: ## Plotting code
let plot = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
plot.addAxis(Axis(orientation: .Horizontal))
plot.addAxis(Axis(orientation: .Vertical))
XCPShowView("Feature", view: plot)

let exampleCount = labels.count
let exampleSize = featureData.count / exampleCount
let points = (0..<exampleCount).map{ index -> Point in
    let value = featureData[index * exampleSize + featureIndex]
    return Point(x: labels[index], y: value)
}

let pointSet = PointSet(points: points)
pointSet.lines = false
pointSet.pointType = .Disk(radius: 2)
plot.addPointSet(pointSet)

plot
