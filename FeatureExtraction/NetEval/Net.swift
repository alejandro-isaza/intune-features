//  Copyright © 2015 Venture Media. All rights reserved.

import BrainCore
import HDF5Kit
import Upsurge

//: Define a DataLayer that returns a static piece of data
class Source : DataLayer {
    var data: Blob
    init(data: Blob) {
        self.data = data
    }
}

//: Define a SinkLayer that stores the last piece of data it got
class Sink : SinkLayer {
    var data: Blob = []
    func consume(input: Blob) {
        data = input
    }
}

class MonophonicNet {
    let netName = "net"
    let featuresName = "testing"

    let featuresPath: String
    let netPath: String
    let net = Net()

    var labels: [Double]
    var bandData: [Double]
    var peakLocationData: [Double]
    var peakHeightData: [Double]

    var bandCount = 0

    var dataLayer = Source(data: [])
    var rmsDataLayer = Source(data: [])
    var sinkLayer = Sink()

    init() {
        featuresPath = NSBundle.mainBundle().pathForResource(featuresName, ofType: "h5")!
        netPath = NSBundle.mainBundle().pathForResource(netName, ofType: "h5")!

        (labels, _) = readData(featuresPath, datasetName: "label")

        var bandsDims: [Int]
        (bandData, bandsDims) = readData(featuresPath, datasetName: "bands")
        (peakLocationData, bandsDims) = readData(featuresPath, datasetName: "peak_locations")
        (peakHeightData, bandsDims) = readData(featuresPath, datasetName: "peak_heights")
        bandCount = bandsDims[1]


        buildNet()
    }

    func buildNet() {
        let dataLayerRef = net.addLayer(dataLayer)

        let ip1Layer = createLayerFromFile(netPath, datasetName: "ip1")
        let ip1LayerRef = net.addLayer(ip1Layer)
        net.connectLayer(dataLayerRef, toLayer: ip1LayerRef)

        let ip1ReluLayerRef = net.addLayer(ReLULayer(size: ip1Layer.outputSize))
        net.connectLayer(ip1LayerRef, toLayer: ip1ReluLayerRef)

        let ip2Layer = createLayerFromFile(netPath, datasetName: "ip2")
        let ip2LayerRef = net.addLayer(ip2Layer)
        net.connectLayer(ip1ReluLayerRef, toLayer: ip2LayerRef)

        let ip2ReluLayerRef = net.addLayer(ReLULayer(size: ip2Layer.outputSize))
        net.connectLayer(ip2LayerRef, toLayer: ip2ReluLayerRef)

        let ip3Layer = createLayerFromFile(netPath, datasetName: "ip3")
        let ip3LayerRef = net.addLayer(ip3Layer)
        net.connectLayer(ip2ReluLayerRef, toLayer: ip3LayerRef)

        let ip3ReluLayerRef = net.addLayer(ReLULayer(size: ip3Layer.outputSize))
        net.connectLayer(ip3LayerRef, toLayer: ip3ReluLayerRef)
        
        let ip4Layer = createLayerFromFile(netPath, datasetName: "ip4")
        let ip4LayerRef = net.addLayer(ip4Layer)
        net.connectLayer(ip3ReluLayerRef, toLayer: ip4LayerRef)
        
        let sinkRef = net.addLayer(sinkLayer)
        net.connectLayer(ip4LayerRef, toLayer: sinkRef)
    }

    func run(exampleIndex: Int) -> RealArray {
        dataLayer.data = RealArray(capacity: bandCount * 3)
        dataLayer.data.appendContentsOf(peakLocationData[exampleIndex*bandCount..<(exampleIndex + 1)*bandCount])
        dataLayer.data.appendContentsOf(peakHeightData[exampleIndex*bandCount..<(exampleIndex + 1)*bandCount])
        dataLayer.data.appendContentsOf(bandData[exampleIndex*bandCount..<(exampleIndex + 1)*bandCount])

        net.forward()

        return sinkLayer.data
    }
}

func readData(filePath: String, datasetName: String) -> ([Double], [Int]) {
    guard let file = File.open(filePath, mode: .ReadOnly) else {
        fatalError("Failed to open file")
    }

    guard let dataset = Dataset.open(file: file, name: datasetName) else {
        fatalError("Failed to open Dataset")
    }

    let size = Int(dataset.space.size)
    var data = [Double](count: size, repeatedValue: 0.0)
    dataset.readDouble(&data)

    return (data, dataset.space.dims.map{ Int($0) })
}

func createLayerFromFile(filePath: String, datasetName: String) -> InnerProductLayer {
    let (weights, dims)  = readData(filePath, datasetName: "\(datasetName)___weight")
    let weightsMatrix = transpose(RealMatrix(rows: dims[0], columns: dims[1], elements: weights))

    let (biases, _) = readData(filePath, datasetName: "\(datasetName)___bias")
    return InnerProductLayer(weights: weightsMatrix, biases: RealArray(biases))
}

func maxi<T: CollectionType where T.Generator.Element: Comparable>(elements: T) -> (Int, T.Generator.Element)? {
    var result: (Int, T.Generator.Element)?
    for (i, v) in elements.enumerate() {
        if let r = result {
            if v > r.1 {
                result = (i, v)
            }
        } else {
            result = (i, v)
        }
    }
    return result
}
