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

class NeuralNet {
    let configuration: Configuration
    let netPath: String
    let device: MTLDevice
    var runner: Runner!

    var dataLayer = Source()
    var notesSinkLayer = Sink()
    var onsetsSinkLayer = Sink()
    var polySinkLayer = Sink()

    var forwardPassAction: ((polyphony: Float, onset: Float, notes: ValueArray<Float>) -> Void)?


    init(file: String, configuration: Configuration) throws {
        self.configuration = configuration
        self.netPath = file
        device = MTLCreateSystemDefaultDevice()!

        let net = buildNet()
        runner = try Runner(net: net, device: device)
        runner.forwardPassAction = {
            self.forwardPassAction?(polyphony: self.polySinkLayer.data[0], onset: self.onsetsSinkLayer.data[0], notes: self.notesSinkLayer.data)
        }
    }


    // MARK: Network definition

    var lstmLayers = [LSTMLayer]()
    var inputSize = 0
    var onsetSize = 0
    var polySize = 0
    var noteSize = 0
    var outputSize = 0

    func titleForOutputIndex(index: Int) -> String {
        if index < noteSize {
            return "\(Note(midiNoteNumber: index + configuration.representableNoteRange.startIndex).description) Output"
        } else if index < noteSize + onsetSize {
            if onsetSize == 1 {
                return "Onset Output"
            } else {
                return "Onset \(index - noteSize) Output"
            }
        } else {
            if polySize == 1 {
                return "Polyphony Output"
            } else {
                return "Polyphony \(index - noteSize - onsetSize) Output"
            }
        }
    }

    func shortTitleForOutputIndex(index: Int) -> String {
        if index < noteSize {
            return "\(Note(midiNoteNumber: index + configuration.representableNoteRange.startIndex).description)"
        } else if index < noteSize + onsetSize {
            if onsetSize == 1 {
                return "Onset"
            } else {
                return "Onset \(index - noteSize)"
            }
        } else {
            if polySize == 1 {
                return "Polyphony"
            } else {
                return "Polyphony \(index - noteSize - onsetSize)"
            }
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

    func processFeature(feature: Feature) {
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
            data[i + 4 * featureSize] = feature.peakFlux[i]
        }

        // Run net
        runner.forward()
    }
}

/// LSTM -> LSTM -> LSTM -> (IP, IP, IP)
extension NeuralNet {
    func buildNet() -> Net {
        let net = Net()

        let lstm0Layer = createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell0BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell0BasicLSTMCellLinearBias")
        let lstm1Layer = createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell1BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell1BasicLSTMCellLinearBias")
        let lstm2Layer = createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell2BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell2BasicLSTMCellLinearBias")
        let noteLayer = createIPLayerFromFile(netPath, weightsName: "note_ip_weights", biasesName: "note_ip_biases")
        let onsetLayer = createIPLayerFromFile(netPath, weightsName: "onset_ip_weights", biasesName: "onset_ip_biases")
        let polyLayer = createIPLayerFromFile(netPath, weightsName: "polyphony_ip_weights", biasesName: "polyphony_ip_biases")

        inputSize = lstm0Layer.inputSize
        let inputBufferRef = net.addBufferWithName("data", size: inputSize)
        let buffer0 = net.addBufferWithName("buffer0", size: lstm0Layer.outputSize)
        let buffer1 = net.addBufferWithName("buffer1", size: lstm1Layer.outputSize)
        let buffer2 = net.addBufferWithName("buffer2", size: lstm2Layer.outputSize)
        let notesBuffer = net.addBufferWithName("notesBuffer", size: noteLayer.outputSize)
        let onsetsBuffer = net.addBufferWithName("onsetsBuffer", size: onsetLayer.outputSize)
        let polyBuffer = net.addBufferWithName("ployBuffer", size: polyLayer.outputSize)

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

        let noteLayerRef = net.addLayer(noteLayer, name: "noteLayer")
        net.connectBuffer(buffer2, atOffset: 0, toLayer: noteLayerRef)
        net.connectLayer(noteLayerRef, toBuffer: notesBuffer)

        let onsetLayerRef = net.addLayer(onsetLayer, name: "onsetLayer")
        net.connectBuffer(buffer2, atOffset: 0, toLayer: onsetLayerRef)
        net.connectLayer(onsetLayerRef, toBuffer: onsetsBuffer)

        let polyLayerRef = net.addLayer(polyLayer, name: "polyLayer")
        net.connectBuffer(buffer2, atOffset: 0, toLayer: polyLayerRef)
        net.connectLayer(polyLayerRef, toBuffer: polyBuffer)

        let onsetsSinkLayerRef = net.addLayer(onsetsSinkLayer, name: "onsets")
        net.connectBuffer(onsetsBuffer, atOffset: 0, toLayer: onsetsSinkLayerRef)

        let polySinkLayerRef = net.addLayer(polySinkLayer, name: "poly")
        net.connectBuffer(polyBuffer, atOffset: 0, toLayer: polySinkLayerRef)

        let notesSinkLayerRef = net.addLayer(notesSinkLayer, name: "notes")
        net.connectBuffer(notesBuffer, atOffset: 0, toLayer: notesSinkLayerRef)
        
        lstmLayers = [lstm0Layer, lstm1Layer, lstm2Layer]
        onsetSize = onsetLayer.outputSize
        polySize = polyLayer.outputSize
        noteSize = noteLayer.outputSize
        outputSize = onsetSize + polySize + noteSize
        
        return net
    }
}
