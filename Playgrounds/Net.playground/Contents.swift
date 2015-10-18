import BrainCore
import FeatureExtraction
import HDF5Kit
import Upsurge

//: ## Helper classes and functions

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

//: Define a function to read data from an h5 file
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
    let (weights, dims)  = readData(filePath, datasetName: "\(datasetName)_weight")
    let weightsMatrix = transpose(Matrix<Double>(rows: dims[0], columns: dims[1], elements: weights))

    let (biases, _) = readData(filePath, datasetName: "\(datasetName)_bias")
    return InnerProductLayer(weights: weightsMatrix, biases: biases)
}

guard let featuresPath = NSBundle.mainBundle().pathForResource("testing", ofType: "h5") else {
    fatalError("File not found")
}
guard let netPath = NSBundle.mainBundle().pathForResource("net", ofType: "h5") else {
    fatalError("File not found")
}


//: ## Network definition
let net = Net()

let (labels, _) = readData(featuresPath, datasetName: "label")
let (bands, _) = readData(featuresPath, datasetName: "bands")
let (peakFrequencies, _) = readData(featuresPath, datasetName: "peak_frequencies")
let (peakHeights, _) = readData(featuresPath, datasetName: "peak_heights")
let (peakFluxes, _) = readData(featuresPath, datasetName: "peak_fluxes")
let (rmsData, _) = readData(featuresPath, datasetName: "rms")
let peakCount = PeakLocationsFeature.peakCount


let bandsDataLayerRef = net.addLayer(Source(data: bands))
let bandsLayer = createLayerFromFile(netPath, datasetName: "bandsIp")
let bandsLayerRef = net.addLayer(bandsLayer)
net.connectLayer(bandsDataLayerRef, toLayer: bandsLayerRef)

let bandsReluLayerRef = net.addLayer(ReLULayer(size: bandsLayer.outputSize))
net.connectLayer(bandsLayerRef, toLayer: bandsReluLayerRef)

var peaks = [Double]()
peaks.appendContentsOf(peakFrequencies)
peaks.appendContentsOf(peakHeights)
peaks.appendContentsOf(peakFluxes)
let peaksDataLayerRef = net.addLayer(Source(data: peaks))
let peaksLayer = createLayerFromFile(netPath, datasetName: "freqIp")
let peaksLayerRef = net.addLayer(peaksLayer)
net.connectLayer(peaksDataLayerRef, toLayer: peaksLayerRef)

let peaksReluLayerRef = net.addLayer(ReLULayer(size: peaksLayer.outputSize))
net.connectLayer(peaksLayerRef, toLayer: peaksReluLayerRef)

let ip2Layer = createLayerFromFile(netPath, datasetName: "ip2")
let ip2LayerRef = net.addLayer(ip2Layer)
net.connectLayer(bandsReluLayerRef, toLayer: ip2LayerRef)
net.connectLayer(peaksReluLayerRef, toLayer: ip2LayerRef)

let ip2ReluLayerRef = net.addLayer(ReLULayer(size: ip2Layer.outputSize))
net.connectLayer(ip2LayerRef, toLayer: ip2ReluLayerRef)

let ip3Layer = createLayerFromFile(netPath, datasetName: "ip3")
let ip3LayerRef = net.addLayer(ip3Layer)
net.connectLayer(ip2ReluLayerRef, toLayer: ip3LayerRef)

let ip3ReluLayerRef = net.addLayer(ReLULayer(size: ip2Layer.outputSize))
net.connectLayer(ip3LayerRef, toLayer: ip3ReluLayerRef)

let ip4Layer = createLayerFromFile(netPath, datasetName: "ip4")
let ip4LayerRef = net.addLayer(ip4Layer)
net.connectLayer(ip3ReluLayerRef, toLayer: ip4LayerRef)

let sink = Sink()
let sinkRef = net.addLayer(sink)
net.connectLayer(ip4LayerRef, toLayer: sinkRef)
net.forward()

sink.data
