//  Copyright © 2015 Venture Media. All rights reserved.

import BrainCore
import FeatureExtraction
import Metal
import HDF5Kit
import Upsurge

//: Define a DataLayer that returns a static piece of data
class Source: DataLayer {
    var data = Blob()

    var outputSize: Int {
        return data.count
    }
}

//: Define a SinkLayer that stores the last piece of data it got
class Sink: SinkLayer {
    var data = Blob()

    func consume(input: Blob) {
        data = input
    }
}

class Snapshot {
    var activations = [Blob]()
    var output = Blob()
}

class NeuralNet {
    let netPath: String
    let device: MTLDevice
    var runner: Runner!

    var dataLayer = Source()
    var sinkLayer = Sink()

    var forwardPassAction: (Snapshot -> Void)?
    var processingCount = 0

    init() throws {
        device = MTLCreateSystemDefaultDevice()!

        self.netPath = NSBundle.mainBundle().pathForResource("net", ofType: "h5")!

        let net = try buildNet()
        runner = try Runner(net: net, device: device)
        runner.forwardPassAction = {
            let snapshot = Snapshot()
            for lstm in self.lstmLayers {
                snapshot.activations.append(valueArrayFromBuffer(lstm.state))
            }

            snapshot.output = ValueArray(self.sinkLayer.data)

            self.forwardPassAction?(snapshot)
        }
    }


    // MARK: Network definition

    var lstmLayers = [LSTMLayer]()
    var outputSize = 0

    func buildNet() throws -> Net {
        let net = Net()

        let lstm0Layer = try createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell0BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell0BasicLSTMCellLinearBias")
        let lstm1Layer = try createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell1BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell1BasicLSTMCellLinearBias")
        let lstm2Layer = try createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell2BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell2BasicLSTMCellLinearBias")
        let ipLayer = try createIPLayerFromFile(netPath, weightsName: "Variable", biasesName: "Variable_1")

        let inputBufferRef = net.addBufferWithName("data", size: lstm0Layer.inputSize)
        let buffer0 = net.addBufferWithName("buffer0", size: lstm0Layer.outputSize)
        let buffer1 = net.addBufferWithName("buffer1", size: lstm1Layer.outputSize)
        let buffer2 = net.addBufferWithName("buffer2", size: lstm2Layer.outputSize)
        let outBuffer = net.addBufferWithName("buffer2", size: ipLayer.outputSize)

        let dataLayerRef = net.addLayer(dataLayer, name: "data")
        net.connectLayer(dataLayerRef, toBuffer: inputBufferRef)

        let lstm0LayerRef = net.addLayer(lstm0Layer, name: "lstm0")
        net.connectBuffer(inputBufferRef, atOffset: 0, toLayer: lstm0LayerRef)
        net.connectLayer(lstm0LayerRef, toBuffer: buffer0)

        let lstm1LayerRef = net.addLayer(lstm1Layer, name: "lstm1")
        net.connectBuffer(buffer0, atOffset: 0, toLayer: lstm1LayerRef)
        net.connectLayer(lstm1LayerRef, toBuffer: buffer1)

        let lstm2LayerRef = net.addLayer(lstm2Layer, name: "lstm2")
        net.connectBuffer(buffer1, atOffset: 0, toLayer: lstm2LayerRef)
        net.connectLayer(lstm2LayerRef, toBuffer: buffer2)

        let ipLayerRef = net.addLayer(ipLayer, name: "ip")
        net.connectBuffer(buffer2, atOffset: 0, toLayer: ipLayerRef)
        net.connectLayer(ipLayerRef, toBuffer: outBuffer)

        let sinkRef = net.addLayer(sinkLayer, name: "sink")
        net.connectBuffer(outBuffer, atOffset: 0, toLayer: sinkRef)

        lstmLayers = [lstm0Layer, lstm1Layer, lstm2Layer]
        outputSize = ipLayer.outputSize

        return net
    }

    func createIPLayerFromFile(filePath: String, weightsName: String, biasesName: String) throws -> InnerProductLayer {
        guard let file = File.open(filePath, mode: .ReadOnly) else {
            fatalError("Failed to open file")
        }

        let weights = loadWeightsFromFile(file, datasetName: weightsName)
        let biases = loadBiasesFromFile(file, datasetName: biasesName)
        let layer = InnerProductLayer(weights: weights, biases: biases)

        print("Loaded \(weightsName) weights with \(weights.rows) rows and \(weights.columns) columns")
        print("Loaded \(biasesName) biases with \(biases.count) elements")
        return layer
    }

    func createLSTMLayerFromFile(filePath: String, weightsName: String, biasesName: String) throws -> LSTMLayer {
        guard let file = File.open(filePath, mode: .ReadOnly) else {
            fatalError("Failed to open file")
        }

        let weights = loadWeightsFromFile(file, datasetName: weightsName)
        let biases = loadBiasesFromFile(file, datasetName: biasesName)
        let layer = LSTMLayer(weights: weights, biases: biases)

        print("Loaded \(weightsName) weights with \(weights.rows) rows and \(weights.columns) columns")
        print("Loaded \(biasesName) biases with \(biases.count) elements")
        return layer
    }

    private func loadWeightsFromFile(file: File, datasetName: String) -> Matrix<Float> {
        guard let dataset = file.openFloatDataset(datasetName) else {
            fatalError("Failed to open Dataset")
        }
        let dims = dataset.space.dims
        let weights = try! dataset.read()

        return Matrix<Float>(rows: dims[0], columns: dims[1], elements: weights)
    }

    private func loadBiasesFromFile(file: File, datasetName: String) -> ValueArray<Float> {
        guard let dataset = file.openFloatDataset(datasetName) else {
            fatalError("Failed to open Dataset")
        }
        return try! ValueArray<Float>(dataset.read())
    }


    // MARK: Network execution

    func processData(data: ValueArray<Double>) {
        let featureBuilder = FeatureBuilder()
        processingCount = 0

        let indices = 0.stride(to: data.count - FeatureBuilder.windowSize - FeatureBuilder.stepSize, by: FeatureBuilder.stepSize)
        for i in indices {
            let feature = featureBuilder.generateFeatures(data[i..<i + FeatureBuilder.windowSize], data[i + FeatureBuilder.stepSize..<i + FeatureBuilder.windowSize + FeatureBuilder.stepSize])
            processFeature(feature)
            processingCount += 1

            print("Processing \(processingCount) of \((data.count - FeatureBuilder.windowSize - FeatureBuilder.stepSize) / FeatureBuilder.stepSize)")
        }
    }

    private func processFeature(feature: Feature) {
        var data = dataLayer.data
        let featureSize = FeatureBuilder.bandNotes.count
        let dataSize = 4 * featureSize
        if data.capacity < dataSize {
            dataLayer.data = ValueArray<Float>(capacity: dataSize)
            data = dataLayer.data
        }

        data.count = dataSize
        for i in 0..<featureSize {
            data[i + 0 * featureSize] = feature.spectrum[i]
            data[i + 1 * featureSize] = feature.peakHeights[i]
            data[i + 2 * featureSize] = feature.peakLocations[i]
            data[i + 3 * featureSize] = feature.spectralFlux[i]
        }
        
        // Run net
        runner.forward()
    }
}
