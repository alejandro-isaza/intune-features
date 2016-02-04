//  Copyright © 2015 Venture Media. All rights reserved.

import BrainCore
import Metal
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

    let deivce: MTLDevice
    let library: MTLLibrary

    let featuresPath: String
    let netPath: String
    let net: Net

    var on_labels: [Float]
    var spectrumData: [Float]
    var fluxData: [Float]
    var peakLocationData: [Float]
    var peakHeightData: [Float]

    var bandCount = 0

    var dataLayer = Source(data: [])
    var rmsDataLayer = Source(data: [])
    var sinkLayer = Sink()

    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to get a Metal device")
        }
        self.deivce = device

        guard let library = device.newDefaultLibrary() else {
            fatalError("Failed to create the Metal default library")
        }
        self.library = library

        net = Net(device: device, library: library)
        featuresPath = NSBundle.mainBundle().pathForResource(featuresName, ofType: "h5")!
        netPath = NSBundle.mainBundle().pathForResource(netName, ofType: "h5")!

        (on_labels, _) = readData(featuresPath, datasetName: "on_label")

        var bandsDims: [Int]
        (spectrumData, bandsDims) = readData(featuresPath, datasetName: "spectrum")
        (fluxData, bandsDims) = readData(featuresPath, datasetName: "spectrum_flux")
        (peakLocationData, bandsDims) = readData(featuresPath, datasetName: "peak_locations")
        (peakHeightData, bandsDims) = readData(featuresPath, datasetName: "peak_heights")
        bandCount = bandsDims[1]

        try! buildNet()
    }

    func buildNet() throws {
        let dataLayerRef = net.addLayer(dataLayer, name: "data")

        let ip1Layer = try createLayerFromFile(netPath, datasetName: "hidden1", library: library)
        let ip1LayerRef = net.addLayer(ip1Layer, name: "hidden1")
        net.connectLayer(dataLayerRef, toLayer: ip1LayerRef)

        let ip1ReluLayerRef = try net.addLayer(ReLULayer(library: library, size: ip1Layer.outputSize), name: "relu1")
        net.connectLayer(ip1LayerRef, toLayer: ip1ReluLayerRef)

        let ip2Layer = try createLayerFromFile(netPath, datasetName: "hidden2", library: library)
        let ip2LayerRef = net.addLayer(ip2Layer, name: "hidden2")
        net.connectLayer(ip1ReluLayerRef, toLayer: ip2LayerRef)

        let ip2ReluLayerRef = try net.addLayer(ReLULayer(library: library, size: ip2Layer.outputSize), name: "relu2")
        net.connectLayer(ip2LayerRef, toLayer: ip2ReluLayerRef)

        let ip3Layer = try createLayerFromFile(netPath, datasetName: "hidden3", library: library)
        let ip3LayerRef = net.addLayer(ip3Layer, name: "hidden3")
        net.connectLayer(ip2ReluLayerRef, toLayer: ip3LayerRef)

//        let ip3ReluLayerRef = try net.addLayer(ReLULayer(library: library, size: ip3Layer.outputSize), name: "relu3")
//        net.connectLayer(ip3LayerRef, toLayer: ip3ReluLayerRef)
//        
//        let ip4Layer = try createLayerFromFile(netPath, datasetName: "ip4", library: library)
//        let ip4LayerRef = net.addLayer(ip4Layer, name: "ip4")
//        net.connectLayer(ip3ReluLayerRef, toLayer: ip4LayerRef)

        let sinkRef = net.addLayer(sinkLayer, name: "sink")
        net.connectLayer(ip3LayerRef, toLayer: sinkRef)
    }

    func run(exampleIndex: Int, completion: ValueArray<Float> -> Void) {
        let start = exampleIndex*bandCount
        let end = start + bandCount
        dataLayer.data = ValueArray<Float>(capacity: bandCount * 4)
        dataLayer.data.appendContentsOf(peakLocationData[start..<end])
        dataLayer.data.appendContentsOf(peakHeightData[start..<end])
        dataLayer.data.appendContentsOf(spectrumData[start..<end])
        dataLayer.data.appendContentsOf(fluxData[start..<end])

        net.forward(completion: {
            dispatch_async(dispatch_get_main_queue()) {
                completion(self.sinkLayer.data)
            }
        })
    }
}

func readData(filePath: String, datasetName: String) -> ([Float], [Int]) {
    guard let file = File.open(filePath, mode: .ReadOnly) else {
        fatalError("Failed to open file")
    }

    guard let dataset = file.openFloatDataset(datasetName) else {
        fatalError("Failed to open Dataset")
    }
    
    let span = [HyperslabIndexType](count: dataset.extent.count, repeatedValue: HyperslabIndex(start: 0, end: (0..).endIndex - 1))
    let data = try! dataset.read(span)
    return (data, dataset.space.dims.map{ Int($0) })
}

func createLayerFromFile(filePath: String, datasetName: String, library: MTLLibrary) throws -> InnerProductLayer {
    let (weights, dims) = readData(filePath, datasetName: "\(datasetName)___weights")
    let weightsMatrix = Matrix<Float>(rows: dims[0], columns: dims[1], elements: weights)
    print("Loaded \(datasetName) weights with \(dims[0]) rows and \(dims[1]) columns")

    let (biases, bdims) = readData(filePath, datasetName: "\(datasetName)___biases")
    print("Loaded \(datasetName) biases with \(bdims[0]) elements")

    return try InnerProductLayer(library: library, weights: weightsMatrix, biases: biases)
}

func maxi(elements: ValueArray<Double>) -> (Int, Double)? {
    var result: (Int, Double)?
    for i in 0..<elements.count {
        let v = elements[i]
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
