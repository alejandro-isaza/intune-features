//  Copyright © 2015 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public extension FeatureDatabase {
    public func shuffle(chunkSize chunkSize: Int, passes: Int = 1, progress: (Double -> Void)? = nil) throws {
        let count = sequenceCount
        if count < 2 * chunkSize {
            // Not enough sequences to shuffle
            return
        }

        let shuffleCount = passes * count / chunkSize
        for i in 0..<shuffleCount {
            let start1 = i * chunkSize % (count - chunkSize + 1)
            let start2 = randomInRange(0...count - chunkSize)
            let indices = (0..<2*chunkSize).shuffle()

            try shuffleTables(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)

            file.flush()
            progress?(Double(i) / Double(shuffleCount - 1))
        }
    }

    func shuffleTables(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) throws {
        let maxFeaturesLength = 44
        let data = RealArray(count: 2 * chunkSize * FeatureBuilder.bandNotes.count * maxFeaturesLength)

        guard let fileIdDataset = file.openIntDataset(FeatureDatabase.fileIdDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.fileIdDatasetName) dataset")
        }
        try shuffle1DDataset(fileIdDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)

        guard let offsetDataset = file.openIntDataset(FeatureDatabase.offsetDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.offsetDatasetName) dataset")
        }
        try shuffle1DDataset(offsetDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)

        guard let sequenceLengthDataset = file.openIntDataset(FeatureDatabase.sequenceLengthDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.sequenceLengthDatasetName) dataset")
        }
        try shuffle1DDataset(sequenceLengthDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)

        guard let featuresLengthDataset = file.openIntDataset(FeatureDatabase.featuresLengthDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.featuresLengthDatasetName) dataset")
        }
        try shuffle1DDataset(featuresLengthDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)

        guard let eventOffsetDataset = file.openIntDataset(FeatureDatabase.eventOffsetDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.eventOffsetDatasetName) dataset")
        }
        try shuffle2DDataset(eventOffsetDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)

        guard let eventNoteDataset = file.openDoubleDataset(FeatureDatabase.eventNoteDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.eventNoteDatasetName) dataset")
        }
        try shuffleDataset(eventNoteDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices, inBuffer: data)

        guard let eventVelocityDataset = file.openDoubleDataset(FeatureDatabase.eventVelocityDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.eventVelocityDatasetName) dataset")
        }
        try shuffleDataset(eventVelocityDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices, inBuffer: data)

        guard let spectrumDataset = file.openDoubleDataset(FeatureDatabase.spectrumDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.spectrumDatasetName) dataset")
        }
        try shuffleDataset(spectrumDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices, inBuffer: data)

        guard let spectralFluxDataset = file.openDoubleDataset(FeatureDatabase.spectrumFluxDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.spectrumFluxDatasetName) dataset")
        }
        try shuffleDataset(spectralFluxDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices, inBuffer: data)

        guard let peakHeightsDataset = file.openDoubleDataset(FeatureDatabase.peakHeightsDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.peakHeightsDatasetName) dataset")
        }
        try shuffleDataset(peakHeightsDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices, inBuffer: data)

        guard let peakLocationsDataset = file.openDoubleDataset(FeatureDatabase.peakLocationsDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.peakLocationsDatasetName) dataset")
        }
        try shuffleDataset(peakLocationsDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices, inBuffer: data)

        guard let featureOnsetValuesDataset = file.openDoubleDataset(FeatureDatabase.featureOnsetValuesDatasetName) else {
            fatalError("File doesn't have a \(FeatureDatabase.featureOnsetValuesDatasetName) dataset")
        }
        try shuffle2DDataset(featureOnsetValuesDataset, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices, inBuffer: data)
    }

    func shuffle2DDataset(dataset: DoubleDataset, chunkSize: Int, start1: Int, start2: Int, indices: [Int], inBuffer data: RealArray) throws {
        let featureCount = dataset.extent[1]

        let filespace1 = dataset.space
        filespace1.select([start1..<start1 + chunkSize, 0..<featureCount])
        try dataset.readInto(data.mutablePointer, memSpace: Dataspace(dims: filespace1.selectionDims), fileSpace: filespace1)

        let filespace2 = dataset.space
        filespace2.select([start2..<start2 + chunkSize, 0..<featureCount])
        try dataset.readInto(data.mutablePointer + chunkSize * featureCount, memSpace: Dataspace(dims: filespace2.selectionDims), fileSpace: filespace2)

        data.count = 2 * chunkSize * featureCount
        for i in 0..<2 * chunkSize {
            let index = indices[i]
            if index != i {
                swapRowsInData(data, rowSize: featureCount, i, index)
            }
        }

        try dataset.writeFrom(data.pointer, memSpace: Dataspace(dims: filespace1.selectionDims), fileSpace: filespace1)
        try dataset.writeFrom(data.pointer + chunkSize * featureCount, memSpace: Dataspace(dims: filespace2.selectionDims), fileSpace: filespace2)
    }

    func shuffleDataset(dataset: DoubleDataset, chunkSize: Int, start1: Int, start2: Int, indices: [Int], inBuffer data: RealArray) throws {
        let eventCount = dataset.extent[1]
        let featureSize = dataset.extent[2]
        let blockSize = eventCount * featureSize

        let filespace1 = dataset.space
        filespace1.select([start1..<start1 + chunkSize, 0..<eventCount, 0..<featureSize])
        try dataset.readInto(data.mutablePointer, memSpace: Dataspace(dims: filespace1.selectionDims), fileSpace: filespace1)

        let filespace2 = dataset.space
        filespace2.select([start2..<start2 + chunkSize, 0..<eventCount, 0..<featureSize])
        try dataset.readInto(data.mutablePointer + chunkSize * blockSize, memSpace: Dataspace(dims: filespace2.selectionDims), fileSpace: filespace2)

        data.count = 2 * chunkSize * blockSize
        for i in 0..<2 * chunkSize {
            let index = indices[i]
            if index != i {
                swapRowsInData(data, rowSize: blockSize, i, index)
            }
        }

        try dataset.writeFrom(data.pointer, memSpace: Dataspace(dims: filespace1.selectionDims), fileSpace: filespace1)
        try dataset.writeFrom(data.pointer + chunkSize * blockSize, memSpace: Dataspace(dims: filespace2.selectionDims), fileSpace: filespace2)
    }

    func swapRowsInData<V: Value>(data: ValueArray<V>, rowSize: Int, _ i: Int, _ j: Int) {
        let start1 = i * rowSize
        let start2 = j * rowSize
        for c in 0..<rowSize {
            swap(&data[start1 + c], &data[start2 + c])
        }
    }

    func shuffle1DDataset(dataset: IntDataset, chunkSize: Int, start1: Int, start2: Int, indices: [Int]) throws {
        let data = ValueArray<Int>(capacity: 2 * chunkSize)

        let filespace1 = dataset.space
        filespace1.select([start1..<start1 + chunkSize])
        try dataset.readInto(data.mutablePointer, memSpace: Dataspace(dims: filespace1.selectionDims), fileSpace: filespace1)

        let filespace2 = dataset.space
        filespace2.select([start2..<start2 + chunkSize])
        try dataset.readInto(data.mutablePointer + chunkSize, memSpace: Dataspace(dims: filespace2.selectionDims), fileSpace: filespace2)

        data.count = 2 * chunkSize
        for i in 0..<2 * chunkSize {
            let index = indices[i]
            if index != i {
                swap(&data[i], &data[index])
            }
        }

        try dataset.writeFrom(data.pointer, memSpace: Dataspace(dims: filespace1.selectionDims), fileSpace: filespace1)
        try dataset.writeFrom(data.pointer + chunkSize, memSpace: Dataspace(dims: filespace2.selectionDims), fileSpace: filespace2)
    }

    func shuffle2DDataset(dataset: IntDataset, chunkSize: Int, start1: Int, start2: Int, indices: [Int]) throws {
        let eventCount = dataset.extent[1]
        let data = ValueArray<Int>(capacity: 2 * chunkSize * eventCount)

        let filespace1 = dataset.space
        filespace1.select([start1..<start1 + chunkSize, 0..<eventCount])
        try dataset.readInto(data.mutablePointer, memSpace: Dataspace(dims: filespace1.selectionDims), fileSpace: filespace1)

        let filespace2 = dataset.space
        filespace2.select([start2..<start2 + chunkSize, 0..<eventCount])
        try dataset.readInto(data.mutablePointer + chunkSize * eventCount, memSpace: Dataspace(dims: filespace2.selectionDims), fileSpace: filespace2)

        data.count = 2 * chunkSize * eventCount
        for i in 0..<2 * chunkSize {
            let index = indices[i]
            if index != i {
                swapRowsInData(data, rowSize: eventCount, i, index)
            }
        }

        try dataset.writeFrom(data.pointer, memSpace: Dataspace(dims: filespace1.selectionDims), fileSpace: filespace1)
        try dataset.writeFrom(data.pointer + chunkSize * eventCount, memSpace: Dataspace(dims: filespace2.selectionDims), fileSpace: filespace2)
    }
}
