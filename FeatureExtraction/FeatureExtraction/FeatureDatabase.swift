//  Copyright © 2015 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public class FeatureDatabase {
    public static let fileListDatasetName = "file_list"
    public static let fileNameDatasetName = "file_name"
    public static let onLabelDatasetName = "on_label"
    public static let onsetLabelDatasetName = "onset_label"
    public static let offsetDatasetName = "offset"
    public static let peakLocationsDatasetName = "peak_locations"
    public static let peakHeightsDatasetName = "peak_heights"
    public static let spectrumDatasetName = "spectrum"
    public static let spectrumFluxDatasetName = "spectrum_flux"

    public static let labelNames = [
        "on_label",
        "onset_label"
    ]
    public static let featureNames = [
        "peak_locations",
        "peak_heights",
        "spectrum",
        "spectrum_flux",
    ]

    let chunkSize: Int
    let filePath: String
    let file: File

    var labelTables = [Table]()
    var featureTables = [Table]()

    let intDatasetSpecs = [
        (name: FeatureDatabase.offsetDatasetName, size: 1)
    ]

    struct IntTable {
        var name: String
        var size: Int
        var data: [Int]
    }

    struct StringTable {
        var name: String
        var data: [String]
    }

    var intTables = [IntTable]()

    public internal(set) var fileList = Set<String>()
    public internal(set) var fileNames = [String]()

    var pendingFeatures = [FeatureData]()

    public init(filePath: String, overwrite: Bool, chunkSize: Int = 1024) {
        self.filePath = filePath
        self.chunkSize = chunkSize
        
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

        for name in FeatureDatabase.labelNames {
            let table = Table(file: file, name: name, rowSize: Label.representableRange.count, chunkSize: chunkSize)
            labelTables.append(table)
        }

        for name in FeatureDatabase.featureNames {
            let table = Table(file: file, name: name, rowSize: FeatureBuilder.bandNotes.count, chunkSize: chunkSize)
            featureTables.append(table)
        }
    }

    func create() {
        for (name, size) in intDatasetSpecs {
            let space = Dataspace(dims: [0, size], maxDims: [-1, size])
            file.createDataset(name, type: Int.self, dataspace: space, chunkDimensions: [chunkSize, size])!
            let table = IntTable(name: name, size: size, data: [Int](count: chunkSize * size, repeatedValue: 0))
            intTables.append(table)
        }
        
        let space = Dataspace(dims: [0], maxDims: [-1])
        file.createDataset(FeatureDatabase.fileNameDatasetName, type: String.self, dataspace: space, chunkDimensions: [chunkSize])!
        file.createDataset(FeatureDatabase.fileListDatasetName, type: String.self, dataspace: space, chunkDimensions: [32])!
    }

    func load() {
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
        
        fileList = readFileList()
    }

    public func readFeatures(start: Int, count: Int) -> [FeatureData] {
        let fileNames = readFileNames(start, count: count)
        let offsets = readOffsets(start, count: count)
        let labels = Label.readFromFile(file, start: start, count: count)

        var features = [FeatureData]()
        features.reserveCapacity(count)

        let data = RealArray(capacity: FeatureBuilder.bandNotes.count)
        for i in 0..<count {
            let feature = FeatureData(filePath: fileNames[i], fileOffset: offsets[i], label: labels[i])
            for table in featureTables {
                try! table.readFromRow(i, count: 1, into: data.mutablePointer)
                feature.features[table.name] = RealArray(data)
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
    
    func readFileList() -> Set<String> {
        let dataset = file.openDataset(FeatureDatabase.fileListDatasetName, type: String.self)!
        
        let fileSpace = Dataspace(dataset.space)
        fileSpace.select(start: [0], stride: nil, count: [fileSpace.size], block: nil)
        
        return Set(dataset.readString(fileSpace: fileSpace))
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

    func readOnsetLabels(start: Int, count: Int) -> [Int] {
        let dataset = file.openDataset(FeatureDatabase.onsetLabelDatasetName, type: Int.self)!

        let fileSpace = Dataspace(dataset.space)
        let featureSize = fileSpace.dims[1]
        fileSpace.select(start: [start, 0], stride: nil, count: [count, featureSize], block: nil)

        let memSpace = Dataspace(dims: [count, featureSize])

        var labels = [Int](count: count * featureSize, repeatedValue: 0)
        dataset.readInt(&labels, memSpace: memSpace, fileSpace: fileSpace)
        return labels
    }

    public func appendFeatures(features: [FeatureData]) {
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

        file.flush()
    }

    func appendChunk(features: ArraySlice<FeatureData>) {
        assert(features.count == chunkSize)

        for table in featureTables {
            appendFeatures(features, toTable: table)
        }

        Label.write(features.map({ $0.label }), toFile: file)

        let offsetsTable = intTables.filter({ $0.name == "offset" }).first!
        appendOffsetsChunk(features, forTable: offsetsTable)

        appendFileNamesChunk(features)
    }

    func appendFeatures(features: ArraySlice<FeatureData>, toTable table: Table) {
        let allData = RealArray(capacity: features.count * FeatureBuilder.bandNotes.count)
        for featureData in features {
            guard let data = featureData.features[table.name] else {
                preconditionFailure("Feature is missing dataset \(table.name)")
            }
            allData.appendContentsOf(data)
        }

        try! table.appendData(allData)
    }

    func appendOffsetsChunk(features: ArraySlice<FeatureData>, var forTable table: IntTable) {
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
        guard let dataset = file.openDataset(FeatureDatabase.fileNameDatasetName, type: String.self) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileNameDatasetName) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize], stride: nil, count: [chunkSize], block: nil)

        let fileNames = features.map{ $0.filePath }
        let newFileNames = Set(fileNames).subtract(fileList)
        
        if !newFileNames.isEmpty {
            appendToFileList(newFileNames)
        }
            
        if !dataset.writeString(fileNames, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    func appendToFileList(files: Set<String>) {
        guard let dataset = file.openDataset(FeatureDatabase.fileListDatasetName, type: String.self) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileListDatasetName) dataset")
        }

        fileList.unionInPlace(files)

        let currentSize = dataset.extent[0]
        dataset.extent[0] += files.count

        let filespace = dataset.space
        filespace.select(start: [currentSize], stride: nil, count: [files.count], block: nil)


        if !dataset.writeString(Array(files), fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    public func shuffle(var chunkSize chunkSize: Int, passes: Int = 1, progress: (Double -> Void)? = nil) {
        let exampleCount = labelTables[0].rowCount
        chunkSize = min(chunkSize, exampleCount/2)
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
    }

    func shuffleDoubleTables(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) {
        let data = RealArray(capacity: 2 * chunkSize * FeatureBuilder.bandNotes.count)
        for table in labelTables {
            shuffleTable(table, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices, inBuffer: data)
        }
        for table in featureTables {
            shuffleTable(table, chunkSize: chunkSize, start1: start1, start2: start2, indices: indices, inBuffer: data)
        }
    }

    func shuffleTable(table: Table, chunkSize: Int, start1: Int, start2: Int, indices: [Int], inBuffer data: RealArray) {
        let count1 = try! table.readFromRow(start1, count: chunkSize, into: data.mutablePointer)
        assert(count1 == chunkSize)

        let count2 = try! table.readFromRow(start2, count: chunkSize, into: data.mutablePointer + chunkSize * table.rowSize)
        assert(count2 == chunkSize)

        data.count = 2 * chunkSize * table.rowSize
        for i in 0..<2 * chunkSize {
            let index = indices[i]
            if index != i {
                swapRowsInData(data, rowSize: table.rowSize, i, index)
            }
        }

        try! table.overwriteFromRow(start1, with: data[0..<chunkSize * table.rowSize])
        try! table.overwriteFromRow(start2, with: data[chunkSize * table.rowSize..<2 * chunkSize * table.rowSize])
    }

    func swapRowsInData(data: RealArray, rowSize: Int, _ i: Int, _ j: Int) {
        let start1 = i * rowSize
        let start2 = j * rowSize
        for c in 0..<rowSize {
            swap(&data[start1 + c], &data[start2 + c])
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
