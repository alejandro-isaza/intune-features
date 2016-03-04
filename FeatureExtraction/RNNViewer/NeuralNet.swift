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
    let configuration: Configuration
    let netPath: String
    let device: MTLDevice
    var runner: Runner!
    let featureBuilder: FeatureBuilder

    var dataLayer = Source()
    var notesSinkLayer = Sink()
    var onsetsSinkLayer = Sink()
    var polySinkLayer = Sink()

    var forwardPassAction: (Snapshot -> Void)?
    var processingCount = 0


    init(configuration: Configuration) throws {
        self.configuration = configuration
        device = MTLCreateSystemDefaultDevice()!
        featureBuilder = FeatureBuilder(configuration: configuration)

        self.netPath = NSBundle.mainBundle().pathForResource("net", ofType: "h5")!

        let net = buildNet()
        runner = try Runner(net: net, device: device)
        runner.forwardPassAction = {
            let snapshot = Snapshot()
            for lstm in self.lstmLayers {
                snapshot.activations.append(valueArrayFromBuffer(lstm.state))
            }


            snapshot.output = ValueArray(capacity: self.outputSize)
            snapshot.output.appendContentsOf(self.notesSinkLayer.data)
            snapshot.output.appendContentsOf(self.onsetsSinkLayer.data)
            snapshot.output.appendContentsOf(self.polySinkLayer.data)

            self.forwardPassAction?(snapshot)
        }
    }


    // MARK: Network definition

    var lstmLayers = [LSTMLayer]()
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

    func processData(data: ValueArray<Double>) {
        processingCount = 0
        for layer in lstmLayers {
            layer.reset()
        }

        let indices = 0.stride(to: data.count - configuration.windowSize - configuration.stepSize, by: configuration.stepSize)
        for i in indices {
            let feature = featureBuilder.generateFeatures(data[i..<i + configuration.windowSize], data[i + configuration.stepSize..<i + configuration.windowSize + configuration.stepSize])
            processFeature(feature)
            processingCount += 1
        }
    }

    private func processFeature(feature: Feature) {
        var data = dataLayer.data
        let featureSize = configuration.bandCount
        let dataSize = 4 * featureSize
        if data.capacity < dataSize {
            dataLayer.data = ValueArray<Float>(capacity: dataSize)
            data = dataLayer.data
        }

        data.count = dataSize
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

/// LSTM -> LSTM -> (IP, IP, IP)
extension NeuralNet {
    func buildNet() -> Net {
        let net = Net()

        let lstm0Layer = createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell0BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell0BasicLSTMCellLinearBias")
        let lstm1Layer = createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell1BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell1BasicLSTMCellLinearBias")
        let noteLayer = createIPLayerFromFile(netPath, weightsName: "note_ip_weights", biasesName: "note_ip_biases")
        let onsetLayer = createIPLayerFromFile(netPath, weightsName: "onset_ip_weights", biasesName: "onset_ip_biases")
        let polyLayer = createIPLayerFromFile(netPath, weightsName: "polyphony_ip_weights", biasesName: "polyphony_ip_biases")

        let inputBufferRef = net.addBufferWithName("data", size: lstm0Layer.inputSize)
        let buffer0 = net.addBufferWithName("buffer0", size: lstm0Layer.outputSize)
        let buffer1 = net.addBufferWithName("buffer1", size: lstm1Layer.outputSize)
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

        let noteLayerRef = net.addLayer(noteLayer, name: "noteLayer")
        net.connectBuffer(buffer1, atOffset: 0, toLayer: noteLayerRef)
        net.connectLayer(noteLayerRef, toBuffer: notesBuffer)

        let onsetLayerRef = net.addLayer(onsetLayer, name: "onsetLayer")
        net.connectBuffer(buffer1, atOffset: 0, toLayer: onsetLayerRef)
        net.connectLayer(onsetLayerRef, toBuffer: onsetsBuffer)

        let polyLayerRef = net.addLayer(polyLayer, name: "polyLayer")
        net.connectBuffer(buffer1, atOffset: 0, toLayer: polyLayerRef)
        net.connectLayer(polyLayerRef, toBuffer: polyBuffer)

        let onsetsSinkLayerRef = net.addLayer(onsetsSinkLayer, name: "onsets")
        net.connectBuffer(onsetsBuffer, atOffset: 0, toLayer: onsetsSinkLayerRef)

        let polySinkLayerRef = net.addLayer(polySinkLayer, name: "poly")
        net.connectBuffer(polyBuffer, atOffset: 0, toLayer: polySinkLayerRef)

        let notesSinkLayerRef = net.addLayer(notesSinkLayer, name: "notes")
        net.connectBuffer(notesBuffer, atOffset: 0, toLayer: notesSinkLayerRef)

        lstmLayers = [lstm0Layer, lstm1Layer]
        onsetSize = onsetLayer.outputSize
        polySize = polyLayer.outputSize
        noteSize = noteLayer.outputSize
        outputSize = onsetSize + polySize + noteSize
        
        return net
    }
}

/// LSTM -> LSTM -> LSTM -> (IP, IP, IP)
//extension NeuralNet {
//    func buildNet() -> Net {
//        let net = Net()
//
//        let lstm0Layer = createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell0BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell0BasicLSTMCellLinearBias")
//        let lstm1Layer = createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell1BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell1BasicLSTMCellLinearBias")
//        let lstm2Layer = createLSTMLayerFromFile(netPath, weightsName: "RNNMultiRNNCellCell2BasicLSTMCellLinearMatrix", biasesName: "RNNMultiRNNCellCell2BasicLSTMCellLinearBias")
//        let noteLayer = createIPLayerFromFile(netPath, weightsName: "note_ip_weights", biasesName: "note_ip_biases")
//        let onsetLayer = createIPLayerFromFile(netPath, weightsName: "onset_ip_weights", biasesName: "onset_ip_biases")
//        let polyLayer = createIPLayerFromFile(netPath, weightsName: "polyphony_ip_weights", biasesName: "polyphony_ip_biases")
//
//        let inputBufferRef = net.addBufferWithName("data", size: lstm0Layer.inputSize)
//        let buffer0 = net.addBufferWithName("buffer0", size: lstm0Layer.outputSize)
//        let buffer1 = net.addBufferWithName("buffer1", size: lstm1Layer.outputSize)
//        let buffer2 = net.addBufferWithName("buffer2", size: lstm2Layer.outputSize)
//        let notesBuffer = net.addBufferWithName("notesBuffer", size: noteLayer.outputSize)
//        let onsetsBuffer = net.addBufferWithName("onsetsBuffer", size: onsetLayer.outputSize)
//        let polyBuffer = net.addBufferWithName("ployBuffer", size: polyLayer.outputSize)
//
//        let dataLayerRef = net.addLayer(dataLayer, name: "data")
//        net.connectLayer(dataLayerRef, toBuffer: inputBufferRef)
//
//        let lstm0LayerRef = net.addLayer(lstm0Layer, name: "lstm0")
//        net.connectBuffer(inputBufferRef, atOffset: 0, toLayer: lstm0LayerRef)
//        net.connectLayer(lstm0LayerRef, toBuffer: buffer0)
//
//        let lstm1LayerRef = net.addLayer(lstm1Layer, name: "lstm1")
//        net.connectBuffer(buffer0, atOffset: 0, toLayer: lstm1LayerRef)
//        net.connectLayer(lstm1LayerRef, toBuffer: buffer1)
//
//        let lstm2LayerRef = net.addLayer(lstm2Layer, name: "lstm2")
//        net.connectBuffer(buffer1, atOffset: 0, toLayer: lstm2LayerRef)
//        net.connectLayer(lstm2LayerRef, toBuffer: buffer2)
//
//        let noteLayerRef = net.addLayer(noteLayer, name: "noteLayer")
//        net.connectBuffer(buffer2, atOffset: 0, toLayer: noteLayerRef)
//        net.connectLayer(noteLayerRef, toBuffer: notesBuffer)
//
//        let onsetLayerRef = net.addLayer(onsetLayer, name: "onsetLayer")
//        net.connectBuffer(buffer2, atOffset: 0, toLayer: onsetLayerRef)
//        net.connectLayer(onsetLayerRef, toBuffer: onsetsBuffer)
//
//        let polyLayerRef = net.addLayer(polyLayer, name: "polyLayer")
//        net.connectBuffer(buffer2, atOffset: 0, toLayer: polyLayerRef)
//        net.connectLayer(polyLayerRef, toBuffer: polyBuffer)
//
//        let onsetsSinkLayerRef = net.addLayer(onsetsSinkLayer, name: "onsets")
//        net.connectBuffer(onsetsBuffer, atOffset: 0, toLayer: onsetsSinkLayerRef)
//
//        let polySinkLayerRef = net.addLayer(polySinkLayer, name: "poly")
//        net.connectBuffer(polyBuffer, atOffset: 0, toLayer: polySinkLayerRef)
//
//        let notesSinkLayerRef = net.addLayer(notesSinkLayer, name: "notes")
//        net.connectBuffer(notesBuffer, atOffset: 0, toLayer: notesSinkLayerRef)
//
//        lstmLayers = [lstm0Layer, lstm1Layer, lstm2Layer]
//        onsetSize = onsetLayer.outputSize
//        polySize = polyLayer.outputSize
//        noteSize = noteLayer.outputSize
//        outputSize = onsetSize + polySize + noteSize
//
//        return net
//    }
//}
