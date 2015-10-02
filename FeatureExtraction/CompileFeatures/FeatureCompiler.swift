//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

import AudioKit
import FeatureExtraction
import HDF5
import Surge

typealias Point = Surge.Point<Double>

class FeatureCompiler {
    let fileListPath = "file.txt"
    let rootPath = ""
    let fileType = "caf"
    let ratio = 10

    let sampleRate = 44100
    let sampleCount: Int

    let startNote = 24
    let peakCount = 10
    let notes = 24...96
    var featureSize: Int

    let fft: FFT
    let fb: Double

    init(sampleCount: Int) {
        self.sampleCount = sampleCount
        fft = FFT(inputLength: sampleCount)
        fb = Double(sampleRate) / Double(sampleCount)
        featureSize = Feature.dataSize(peakCount, noteCount: notes.count)
    }
    
    func compileFeatures() {
        let fileCollector = FileCollector(noteRange: notes, fileType: fileType)
        let examples = fileCollector.buildExamples()

        print("")
        print("Processing...")
        let features = generateFeatures(examples)
        splitAndWriteFeatures(features)
    }
    
    func generateFeatures(examples: [FileCollector.Example]) -> [Feature] {
        var features = [Feature]()
        var data = [Double](count: sampleCount, repeatedValue: 0.0)
        for example in examples {
            var featureSet = Feature(peakCount: peakCount, noteCount: notes.count)
            featureSet.label = example.label
            
            let audioFile = AudioFile(filePath: example.filePath)!
            assert(audioFile.sampleRate == 44100)
            
            audioFile.readFrames(&data, count: sampleCount)
            
            let psd = sqrt(fft.forwardMags(data))
            
            let fftPoints = (0..<psd.count).map{ Point(x: fb * Double($0), y: psd[$0]) }
            let peaks = PeakExtractor.process(fftPoints).sort{ $0.y > $1.y }
            if peaks.count >= peakCount {
                featureSet.peaks = Array(peaks[0..<peakCount])
            } else {
                featureSet.peaks = [Point](count: peakCount, repeatedValue: Point())
                featureSet.peaks.replaceRange((0..<peaks.count), with: peaks)
            }
                
            let bands = BandExtractor.process(spectrumData: psd, notes: notes, baseFrequency: fb)
            featureSet.bands = bands
            
            features.append(featureSet)
        }
        return features
    }

    func splitAndWriteFeatures(features: [Feature]) {
        let split = features.count/ratio

        let testingFeatures = features[0..<split]
        let (testingData, testingLabels) = serializeFeatures(testingFeatures)
        writeFeatures(testingData, labels: testingLabels, fileName: "testing.h5")
        
        let trainingFeatures = features[split..<features.count]
        let (trainingData, trainingLabels) = serializeFeatures(trainingFeatures)
        writeFeatures(trainingData, labels: trainingLabels, fileName: "training.h5")

        print("Generated \(testingFeatures.count) testing and \(trainingFeatures.count) training features")
    }

    func serializeFeatures(features: ArraySlice<Feature>) -> ([Double], [Int]) {
        var data = [Double]()
        data.reserveCapacity(features.count * featureSize)

        var labels = [Int]()
        labels.reserveCapacity(features.count)

        for feature in features {
            data.appendContentsOf(feature.data())
            labels.append(feature.label)
        }
        return (data, labels)
    }

    func writeFeatures(data: [Double], labels: [Int], fileName: String) {
        precondition(data.count == labels.count * featureSize)

        guard let hdf5File = HDF5.File.create(fileName, mode: File.CreateMode.Truncate) else {
            fatalError("Could not create HDF5 dataset.")
        }

        let dataType = HDF5.Datatype.copy(type: .Double)
        let dataDataspace = Dataspace(dims: [UInt64(labels.count), UInt64(featureSize)])
        let dataDataset = HDF5.Dataset.create(file: hdf5File, name: "data", datatype: dataType, dataspace: dataDataspace)
        dataDataset.writeDouble(data)

        let labelType = HDF5.Datatype.copy(type: .Int)
        let labelDataspace = Dataspace(dims: [UInt64(labels.count)])
        let labelsDataset = HDF5.Dataset.create(file: hdf5File, name: "labels", datatype: labelType, dataspace: labelDataspace)
        labelsDataset.writeInt(labels)
    }

}

