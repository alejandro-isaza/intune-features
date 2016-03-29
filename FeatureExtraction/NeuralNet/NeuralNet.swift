//  Copyright © 2015 Venture Media. All rights reserved.

import BrainCore
import FeatureExtraction
import Metal
import HDF5Kit
import Upsurge

/// Define a DataLayer that returns a static piece of data
class Source: DataLayer {
    var data = Blob()

    var outputSize: Int {
        return data.count
    }
}

/// Define a SinkLayer that stores the last piece of data it got
class Sink: SinkLayer {
    var data = Blob()

    func consume(input: Blob) {
        data = input
    }
}

/// A network snapshot. This includes the output of the network and the LSTM layer activation buffers.
public struct Snapshot {
    public var onset: Float
    public var polyphony: Float
    public var notes: Blob
    public var activationBuffers = [MTLBuffer]()

    public init(onset: Float, polyphony: Float, notes: Blob) {
        self.onset = onset
        self.polyphony = polyphony
        self.notes = notes
    }
}

public class NeuralNet {
    public let configuration: Configuration
    let netPath: String
    let device: MTLDevice
    var runner: Runner!
    let featureBuilder: FeatureBuilder

    var dataLayer = Source()
    var notesSinkLayer = Sink()
    var onsetsSinkLayer = Sink()
    var polySinkLayer = Sink()

    public var forwardPassAction: (Snapshot -> Void)?
    public internal(set) var processingCount = 0


    public convenience init(configuration: Configuration) throws {
        let path = NSBundle(forClass: NeuralNet.self).pathForResource("net", ofType: "h5")!
        try self.init(file: path, configuration: configuration)
    }

    public init(file: String, configuration: Configuration) throws {
        self.netPath = file
        self.configuration = configuration

        device = MTLCreateSystemDefaultDevice()!
        featureBuilder = FeatureBuilder(configuration: configuration)

        let net = buildNet()
        runner = try Runner(net: net, device: device)
        runner.forwardPassAction = { buffers in
            var snapshot = Snapshot(onset: self.onsetsSinkLayer.data[0], polyphony: self.polySinkLayer.data[0], notes: self.notesSinkLayer.data)
            for lstm in self.lstmLayers {
                snapshot.activationBuffers.append(lstm.stateBuffer)
            }

            self.forwardPassAction?(snapshot)
        }
    }


    // MARK: Network definition

    public internal(set) var lstmLayers = [LSTMLayer]()
    public internal(set) var inputSize = 0
    public internal(set) var noteSize = 0
    public internal(set) var outputSize = 0

    public func titleForOutputIndex(index: Int) -> String {
        if index < noteSize {
            return "\(Note(midiNoteNumber: index + configuration.representableNoteRange.startIndex).description) Output"
        } else if index < noteSize + 1 {
            return "Onset Output"
        } else {
            return "Polyphony Output"
        }
    }

    public func shortTitleForOutputIndex(index: Int) -> String {
        if index < noteSize {
            return "\(Note(midiNoteNumber: index + configuration.representableNoteRange.startIndex).description)"
        } else if index < noteSize + 1 {
            return "Onset"
        } else {
            return "Polyphony"
        }
    }

    func createIPLayerFromFile(filePath: String, weightsName: String, biasesName: String) -> InnerProductLayer {
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

    func createLSTMLayerFromFile(filePath: String, weightsName: String, biasesName: String) -> LSTMLayer {
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

    public func reset() {
        processingCount = 0
        for layer in lstmLayers {
            layer.reset()
        }
    }

    public func processData(data: ValueArray<Double>) {
        reset()

        let indices = 0.stride(to: data.count - configuration.windowSize - configuration.stepSize, by: configuration.stepSize)
        for i in indices {
            let feature = featureBuilder.generateFeatures(data[i..<i + configuration.windowSize], data[i + configuration.stepSize..<i + configuration.windowSize + configuration.stepSize])
            processFeature(feature)
        }
    }

    public func processFeature(feature: Feature) {
        processingCount += 1

        var data = dataLayer.data
        let featureSize = configuration.bandCount
        if data.capacity < inputSize {
            dataLayer.data = ValueArray<Float>(capacity: inputSize)
            data = dataLayer.data
        }

        data.count = inputSize
        for i in 0..<inputSize {
            data[i] = Float.NaN
        }

        for i in 0..<featureSize {
            data[i + 0 * featureSize] = feature.spectrum[i]
            data[i + 1 * featureSize] = feature.spectralFlux[i]
            data[i + 2 * featureSize] = feature.peakHeights[i]
            data[i + 3 * featureSize] = feature.peakLocations[i]
        }
        
        // Run net
        runner.forward()
    }
}

/// LSTM -> (IP, IP, IP)
extension NeuralNet {
    func buildNet() -> Net {
        let net = Net()

        let lstm0Layer = createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell0BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell0BasicLSTMCellLinearBias")
        let noteLayer = createIPLayerFromFile(netPath, weightsName: "note_ip_weights", biasesName: "note_ip_biases")
        let onsetLayer = createIPLayerFromFile(netPath, weightsName: "onset_ip_weights", biasesName: "onset_ip_biases")
        let polyLayer = createIPLayerFromFile(netPath, weightsName: "polyphony_ip_weights", biasesName: "polyphony_ip_biases")

        inputSize = lstm0Layer.inputSize
        let inputBufferRef = net.addBufferWithName("data", size: inputSize)
        let buffer0 = net.addBufferWithName("buffer0", size: lstm0Layer.outputSize)
        let notesBuffer = net.addBufferWithName("notesBuffer", size: noteLayer.outputSize)
        let onsetsBuffer = net.addBufferWithName("onsetsBuffer", size: onsetLayer.outputSize)
        let polyBuffer = net.addBufferWithName("ployBuffer", size: polyLayer.outputSize)

        let dataLayerRef = net.addLayer(dataLayer, name: "data")
        net.connectLayer(dataLayerRef, toBuffer: inputBufferRef)

        let lstm0LayerRef = net.addLayer(lstm0Layer, name: "lstm0")
        net.connectBuffer(inputBufferRef, atOffset: 0, toLayer: lstm0LayerRef)
        net.connectLayer(lstm0LayerRef, toBuffer: buffer0)

        let noteLayerRef = net.addLayer(noteLayer, name: "noteLayer")
        net.connectBuffer(buffer0, atOffset: 0, toLayer: noteLayerRef)
        net.connectLayer(noteLayerRef, toBuffer: notesBuffer)

        let onsetLayerRef = net.addLayer(onsetLayer, name: "onsetLayer")
        net.connectBuffer(buffer0, atOffset: 0, toLayer: onsetLayerRef)
        net.connectLayer(onsetLayerRef, toBuffer: onsetsBuffer)

        let polyLayerRef = net.addLayer(polyLayer, name: "polyLayer")
        net.connectBuffer(buffer0, atOffset: 0, toLayer: polyLayerRef)
        net.connectLayer(polyLayerRef, toBuffer: polyBuffer)

        let onsetsSinkLayerRef = net.addLayer(onsetsSinkLayer, name: "onsets")
        net.connectBuffer(onsetsBuffer, atOffset: 0, toLayer: onsetsSinkLayerRef)

        let polySinkLayerRef = net.addLayer(polySinkLayer, name: "poly")
        net.connectBuffer(polyBuffer, atOffset: 0, toLayer: polySinkLayerRef)

        let notesSinkLayerRef = net.addLayer(notesSinkLayer, name: "notes")
        net.connectBuffer(notesBuffer, atOffset: 0, toLayer: notesSinkLayerRef)

        lstmLayers = [lstm0Layer]
        noteSize = noteLayer.outputSize
        outputSize = 2 + noteSize

        return net
    }
}
