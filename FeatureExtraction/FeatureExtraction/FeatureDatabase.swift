//  Copyright © 2015 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public class FeatureDatabase {
    let chunkSize = 1024

    public static let fileNameDatasetName = "fileName"
    public static let folderDatasetName = "folder"
    public static let labelDatasetName = "label"
    public static let offsetDatasetName = "offset"
    public static let peakLocationsDatasetName = "peak_locations"
    public static let peakHeightsDatasetName = "peak_heights"
    public static let spectrumDatasetName = "spectrum"
    public static let spectrumFluxDatasetName = "spectrum_flux"

    let filePath: String
    let file: File

    let doubleDatasetSpecs = [
        (name: FeatureDatabase.peakLocationsDatasetName, size: FeatureBuilder.bandNotes.count),
        (name: FeatureDatabase.peakHeightsDatasetName, size: FeatureBuilder.bandNotes.count),
        (name: FeatureDatabase.spectrumDatasetName, size: FeatureBuilder.bandNotes.count),
        (name: FeatureDatabase.spectrumFluxDatasetName, size: FeatureBuilder.bandNotes.count)
    ]
    let intDatasetSpecs = [
        (name: FeatureDatabase.labelDatasetName, size: FeatureBuilder.bandNotes.count),
        (name: FeatureDatabase.offsetDatasetName, size: 1),
    ]

    struct DoubleTable {
        var name: String
        var size: Int
        var data: RealArray
    }

    struct IntTable {
        var name: String
        var size: Int
        var data: [Int]
    }

    struct StringTable {
        var name: String
        var data: [String]
    }

    var doubleTables = [DoubleTable]()
    var intTables = [IntTable]()
    var fileNamesData = [String]()

    public internal(set) var folders = [String]()
    public internal(set) var exampleCount = 0

    var pendingFeatures = [FeatureData]()

    public init(filePath: String, overwrite: Bool) {
        self.filePath = filePath

        if overwrite {
            file = File.create(filePath, mode: .Truncate)!
            create()
        } else if let file = File.open(filePath, mode: .ReadWrite) {
            self.file = file
            load()
        } else {
            file = File.create(filePath, mode: .Exclusive)!
            create()
        }
    }

    func create() {
        let chunkSize = FeatureDatabase.chunkSize

        for (name, size) in doubleDatasetSpecs {
            let space = Dataspace(dims: [0, size], maxDims: [-1, size])
            file.createDataset(name, type: Double.self, dataspace: space, chunkDimensions: [chunkSize, size])!
            let table = DoubleTable(name: name, size: size, data: RealArray(count: chunkSize * size))
            doubleTables.append(table)
        }
        for (name, size) in intDatasetSpecs {
            let space = Dataspace(dims: [0, size], maxDims: [-1, size])
            file.createDataset(name, type: Int.self, dataspace: space, chunkDimensions: [chunkSize, size])!
            let table = IntTable(name: name, size: size, data: [Int](count: chunkSize * size, repeatedValue: 0))
            intTables.append(table)
        }

        let space = Dataspace(dims: [0], maxDims: [-1])
        file.createDataset(FeatureDatabase.fileNameDatasetName, type: String.self, dataspace: space, chunkDimensions: [chunkSize])!
        file.createDataset(FeatureDatabase.folderDatasetName, type: String.self, dataspace: space, chunkDimensions: [1])!
    }

    func load() {
        let chunkSize = FeatureDatabase.chunkSize

        for (name, size) in doubleDatasetSpecs {
            guard let dataset = file.openDataset(name, type: Double.self) else {
                preconditionFailure("Existing file doesn't have a \(name) dataset")
            }

            guard let nativeType = dataset.type.nativeType else {
                preconditionFailure("Existing dataset '\(name)' is not of a native data type")
            }
            precondition(nativeType == .Double, "Existing dataset '\(name)' is of the wrong type")

            let dims = dataset.space.dims
            precondition(dims.count == 2 && dims[1] == size, "Existing dataset '\(name)' is of the wrong size")
            exampleCount = dims[0]
            
            let table = DoubleTable(name: name, size: size, data: RealArray(count: size * chunkSize))
            doubleTables.append(table)
        }
        for (name, size) in intDatasetSpecs {
            guard let dataset = file.openDataset(name, type: Int.self) else {
                preconditionFailure("Existing file doesn't have a \(name) dataset")
            }

            guard let nativeType = dataset.type.nativeType else {
                preconditionFailure("Existing dataset '\(name)' is not of a native data type")
            }
            precondition(nativeType == .Int, "Existing dataset '\(name)' is of the wrong type")

            let dims = dataset.space.dims
            precondition(dims.count == 2 && dims[1] == size, "Existing dataset '\(name)' is of the wrong size")

            let table = IntTable(name: name, size: size, data: [Int](count: size * chunkSize, repeatedValue: 0))
            intTables.append(table)
        }

        guard let dataset = file.openDataset(FeatureDatabase.fileNameDatasetName, type: String.self) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileNameDatasetName) dataset")
        }
        precondition(dataset.space.dims.count == 1, "Existing dataset '\(FeatureDatabase.fileNameDatasetName)' is of the wrong size")

        guard let foldersDataset = file.openDataset(FeatureDatabase.folderDatasetName, type: Double.self) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.folderDatasetName) dataset")
        }
        folders = foldersDataset.readString()
    }

    public func readFeatures(start: Int, count: Int) -> [FeatureData] {
        let fileNames = readFileNames(start, count: count)
        let offsets = readOffsets(start, count: count)
        let labels = readLabels(start, count: count)

        for table in doubleTables {
            let dataset = file.openDataset(table.name, type: Double.self)!

            let fileSpace = Dataspace(dataset.space)
            let featureSize = fileSpace.dims[1]
            fileSpace.select(start: [start, 0], stride: nil, count: [count, featureSize], block: nil)

            let memSpace = Dataspace(dims: [count, featureSize])

            dataset.readDouble(table.data.mutablePointer, memSpace: memSpace, fileSpace: fileSpace)
        }

        let labelSize = labels.count / count

        var features = [FeatureData]()
        features.reserveCapacity(count)

        for i in 0..<count {
            let label = [Int](labels[i..<i + labelSize])
            let feature = FeatureData(filePath: fileNames[i], fileOffset: offsets[i], label: label)
            for table in doubleTables {
                feature.features[table.name] = RealArray(table.data[i..<i + table.size])
            }
            features.append(feature)
        }
        return features
    }

    func readFileNames(start: Int, count: Int) -> [String] {
        let dataset = file.openDataset(FeatureDatabase.fileNameDatasetName, type: String.self)!

        let fileSpace = Dataspace(dataset.space)
        fileSpace.select(start: [start], stride: nil, count: [count], block: nil)

        return dataset.readString(fileSpace: fileSpace)
    }

    func readOffsets(start: Int, count: Int) -> [Int] {
        let dataset = file.openDataset(FeatureDatabase.offsetDatasetName, type: Int.self)!

        let fileSpace = Dataspace(dataset.space)
        fileSpace.select(start: [start, 0], stride: nil, count: [count, 1], block: nil)

        let memSpace = Dataspace(dims: [count, 1])

        var offsets = [Int](count: count, repeatedValue: 0)
        if !dataset.readInt(&offsets, memSpace: memSpace, fileSpace: fileSpace) {
            fatalError("Failed to read offsets")
        }
        return offsets
    }

    func readLabels(start: Int, count: Int) -> [Int] {
        let dataset = file.openDataset(FeatureDatabase.labelDatasetName, type: Int.self)!

        let fileSpace = Dataspace(dataset.space)
        let featureSize = fileSpace.dims[1]
        fileSpace.select(start: [start, 0], stride: nil, count: [count, featureSize], block: nil)

        let memSpace = Dataspace(dims: [count, featureSize])

        var labels = [Int](count: count * featureSize, repeatedValue: 0)
        dataset.readInt(&labels, memSpace: memSpace, fileSpace: fileSpace)
        return labels
    }

    public func appendFeatures(features: [FeatureData], folder: String?) {
        let chunkSize = FeatureDatabase.chunkSize
        var offset = 0

        if pendingFeatures.count > 0 {
            let missing = chunkSize - pendingFeatures.count
            offset = min(missing, features.count)
            pendingFeatures += features[0..<offset]
            if pendingFeatures.count < chunkSize {
                // Not enough data for a full chunk
                return
            }
        }

        if pendingFeatures.count == chunkSize {
            appendChunk(ArraySlice(pendingFeatures))
            pendingFeatures.removeAll(keepCapacity: true)
        }

        while features.count - offset >= chunkSize {
            appendChunk(features[offset..<offset + chunkSize])
            offset += chunkSize
        }

        pendingFeatures += features[offset..<features.count]

        if let folder = folder {
            appendFolder(folder)
        }

        file.flush()
    }

    func appendChunk(features: ArraySlice<FeatureData>) {
        assert(features.count == FeatureDatabase.chunkSize)

        for table in doubleTables {
            appendDoubleChunk(features, forTable: table)
        }

        let labelsTable = intTables.filter({ $0.name == "label" }).first!
        appendLabelsChunk(features, forTable: labelsTable)

        let offsetsTable = intTables.filter({ $0.name == "offset" }).first!
        appendOffsetsChunk(features, forTable: offsetsTable)

        appendFileNamesChunk(features)

        exampleCount += features.count
    }

    func appendDoubleChunk(features: ArraySlice<FeatureData>, forTable table: DoubleTable) {
        let chunkSize = FeatureDatabase.chunkSize

        guard let dataset = file.openDataset(table.name, type: Double.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

        assert(table.data.capacity == chunkSize * table.size)
        table.data.count = 0
        let memspace = Dataspace(dims: [chunkSize, table.size])

        for featureData in features {
            guard let data = featureData.features[table.name] else {
                fatalError("Feature is missing dataset \(table.name)")
            }
            table.data.appendContentsOf(data)
        }

        if !dataset.writeDouble(table.data.pointer, memSpace: memspace, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    func appendLabelsChunk(features: ArraySlice<FeatureData>, var forTable table: IntTable) {
        let chunkSize = FeatureDatabase.chunkSize

        guard let dataset = file.openDataset(table.name, type: Int.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

        table.data.removeAll(keepCapacity: true)
        let memspace = Dataspace(dims: [chunkSize, table.size])

        for feature in features {
            table.data.appendContentsOf(feature.label)
        }
        if !dataset.writeInt(table.data.pointer, memSpace: memspace, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    func appendOffsetsChunk(features: ArraySlice<FeatureData>, var forTable table: IntTable) {
        let chunkSize = FeatureDatabase.chunkSize

        guard let dataset = file.openDataset(table.name, type: Int.self) else {
            preconditionFailure("Existing file doesn't have a \(table.name) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

        table.data.removeAll(keepCapacity: true)
        let memspace = Dataspace(dims: [chunkSize, table.size])

        for feature in features {
            table.data.append(feature.fileOffset)
        }
        if !dataset.writeInt(table.data.pointer, memSpace: memspace, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    func appendFileNamesChunk(features: ArraySlice<FeatureData>) {
        let chunkSize = FeatureDatabase.chunkSize

        guard let dataset = file.openDataset(FeatureDatabase.fileNameDatasetName, type: String.self) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileNameDatasetName) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize], stride: nil, count: [chunkSize], block: nil)

        fileNamesData.removeAll(keepCapacity: true)

        for feature in features {
            fileNamesData.append(feature.filePath)
        }
        if !dataset.writeString(fileNamesData, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    func appendFolder(folder: String) {
        guard let dataset = file.openDataset(FeatureDatabase.folderDatasetName, type: String.self) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.folderDatasetName) dataset")
        }

        folders.append(folder)

        let currentSize = dataset.extent[0]
        dataset.extent[0] += 1

        let filespace = dataset.space
        filespace.select(start: [currentSize], stride: nil, count: [1], block: nil)


        let data = [folder]
        if !dataset.writeString(data, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    public func shuffle(chunkSize chunkSize: Int, passes: Int = 1, progress: (Double -> Void)? = nil) {
        let shuffleCount = passes * exampleCount / chunkSize
        for i in 0..<shuffleCount {
            let start1 = i * chunkSize % (exampleCount - chunkSize + 1)
            let start2 = randomInRange(0...exampleCount - chunkSize)
            let indices = (0..<2*chunkSize).shuffle()

            shuffleDoubleTables(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)
            shuffleIntTables(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)
            shuffleStringTables(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)

            file.flush()
            progress?(Double(i) / Double(shuffleCount - 1))
        }
        file.flush()
    }

    func shuffleDoubleTables(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) {
        var data = [Double](count: 2*chunkSize*FeatureBuilder.bandNotes.count, repeatedValue: 0)
        for table in doubleTables {
            guard let dataset = file.openDataset(table.name, type: Double.self) else {
                preconditionFailure("Existing file doesn't have a \(table.name) dataset")
            }

            let memspace1 = Dataspace(dims: [2*chunkSize, table.size])
            memspace1.select(start: [0, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            let filespace1 = Dataspace(dataset.space)
            filespace1.select(start: [start1, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            assert(data.count >= memspace1.selectionSize)
            dataset.readDouble(&data, memSpace: memspace1, fileSpace: filespace1)

            let memspace2 = Dataspace(dims: [2*chunkSize, table.size])
            memspace2.select(start: [chunkSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            let filespace2 = Dataspace(dataset.space)
            filespace2.select(start: [start2, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            assert(data.count - chunkSize >= memspace1.selectionSize)
            dataset.readDouble(&data, memSpace: memspace2, fileSpace: filespace2)

            for i in 0..<2*chunkSize {
                let index = indices[i]
                if index != i {
                    swap(&data[i], &data[index])
                }
            }

            dataset.writeDouble(data, memSpace: memspace1, fileSpace: filespace1)
            dataset.writeDouble(data, memSpace: memspace2, fileSpace: filespace2)
        }
    }

    func shuffleIntTables(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) {
        var data = [Int](count: 2*chunkSize*FeatureBuilder.bandNotes.count, repeatedValue: 0)
        for table in intTables {
            guard let dataset = file.openDataset(table.name, type: Int.self) else {
                preconditionFailure("Existing file doesn't have a \(table.name) dataset")
            }

            let memspace1 = Dataspace(dims: [2*chunkSize, table.size])
            memspace1.select(start: [0, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            let filespace1 = Dataspace(dataset.space)
            filespace1.select(start: [start1, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            assert(data.count >= memspace1.selectionSize)
            dataset.readInt(&data, memSpace: memspace1, fileSpace: filespace1)

            let memspace2 = Dataspace(dims: [2*chunkSize, table.size])
            memspace2.select(start: [chunkSize, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            let filespace2 = Dataspace(dataset.space)
            filespace2.select(start: [start2, 0], stride: nil, count: [chunkSize, table.size], block: nil)

            assert(data.count - chunkSize >= memspace1.selectionSize)
            dataset.readInt(&data, memSpace: memspace2, fileSpace: filespace2)

            for i in 0..<2*chunkSize {
                let index = indices[i]
                if index != i {
                    swap(&data[i], &data[index])
                }
            }

            dataset.writeInt(data, memSpace: memspace1, fileSpace: filespace1)
            dataset.writeInt(data, memSpace: memspace2, fileSpace: filespace2)
        }
    }

    func shuffleStringTables(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) {
        guard let dataset = file.openDataset(FeatureDatabase.fileNameDatasetName, type: String.self) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileNameDatasetName) dataset")
        }

        let filespace1 = Dataspace(dataset.space)
        filespace1.select(start: [start1], stride: nil, count: [chunkSize], block: nil)
        var strings1 = dataset.readString(fileSpace: filespace1)
        assert(strings1.count == filespace1.selectionSize)

        let filespace2 = Dataspace(dataset.space)
        filespace2.select(start: [start2], stride: nil, count: [chunkSize], block: nil)
        var strings2 = dataset.readString(fileSpace: filespace2)
        assert(strings2.count == filespace2.selectionSize)

        var strings = strings1 + strings2

        for i in 0..<2*chunkSize {
            let index = indices[i]
            if index != i {
                swap(&strings[i], &strings[index])
            }
        }

        strings1 = [String](strings.dropLast(chunkSize))
        strings2 = [String](strings.dropFirst(chunkSize))
        dataset.writeString(strings1, fileSpace: filespace1)
        dataset.writeString(strings2, fileSpace: filespace2)
    }
}
