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

    public static let featureNames = [
        peakLocationsDatasetName,
        peakHeightsDatasetName,
        spectrumDatasetName,
        spectrumFluxDatasetName,
    ]
    public static let labelNames = [
        onLabelDatasetName,
        onsetLabelDatasetName,
    ]

    let chunkSize: Int
    let filePath: String
    let file: File

    var labelTables = [Table]()
    var featureTables = [Table]()

    struct StringTable {
        var name: String
        var data: [String]
    }

    var intTables = [IntTable]()

    public internal(set) var fileList = Set<String>()
    public internal(set) var fileNames = [String]()

    var pendingFeatures = [FeatureData]()
    
    public var exampleCount: Int {
        return labelTables.first?.rowCount ?? 0
    }

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
            let table = Table(file: file, name: name, rowSize: Label.noteCount, chunkSize: chunkSize)
            labelTables.append(table)
        }

        for name in FeatureDatabase.featureNames {
            let table = Table(file: file, name: name, rowSize: FeatureBuilder.bandNotes.count, chunkSize: chunkSize)
            featureTables.append(table)
        }

        let _ = IntTable(file: file, name: FeatureDatabase.offsetDatasetName, rowSize: 1)
    }

    func create() {
        let space = Dataspace(dims: [0], maxDims: [-1])
        file.createStringDataset(FeatureDatabase.fileNameDatasetName, dataspace: space, chunkDimensions: [chunkSize])!
        file.createStringDataset(FeatureDatabase.fileListDatasetName, dataspace: space, chunkDimensions: [32])!
    }

    func load() {
        guard let dataset = file.openStringDataset(FeatureDatabase.fileNameDatasetName) else {
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

        let data = RealArray(count: FeatureBuilder.bandNotes.count, repeatedValue: 0)
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
        let dataset = file.openStringDataset(FeatureDatabase.fileNameDatasetName)!
        return dataset[start..<start + count]
    }

    func readFileList() -> Set<String> {
        let dataset = file.openStringDataset(FeatureDatabase.fileListDatasetName)!
        return Set(dataset[0..])
    }

    func readOffsets(start: Int, count: Int) -> [Int] {
        let dataset = file.openIntDataset(FeatureDatabase.offsetDatasetName)!
        return dataset[start..<start + count, 0]
    }

    public func appendFeatures(features: [FeatureData]) throws {
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
            try appendChunk(ArraySlice(pendingFeatures))
            pendingFeatures.removeAll(keepCapacity: true)
        }

        while features.count - offset >= chunkSize {
            try appendChunk(features[offset..<offset + chunkSize])
            offset += chunkSize
        }

        pendingFeatures += features[offset..<features.count]

        file.flush()
    }

    func appendChunk(features: ArraySlice<FeatureData>) throws {
        assert(features.count == chunkSize)

        for table in featureTables {
            appendFeatures(features, toTable: table)
        }

        Label.write(features.map({ $0.label }), toFile: file)
        appendOffsetsChunk(features)
        try appendFileNamesChunk(features)
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

    func appendOffsetsChunk(features: ArraySlice<FeatureData>) {
        let table = IntTable(file: file, name: FeatureDatabase.offsetDatasetName, rowSize: 1)

        var data = [Int]()
        data.reserveCapacity(features.count)
        for feature in features {
            data.append(feature.fileOffset)
        }

        try! table.appendData(data)
    }

    func appendFileNamesChunk(features: ArraySlice<FeatureData>) throws {
        guard let dataset = file.openStringDataset(FeatureDatabase.fileNameDatasetName) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileNameDatasetName) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += chunkSize

        let filespace = dataset.space
        filespace.select(start: [currentSize], stride: nil, count: [chunkSize], block: nil)

        let fileNames = features.map{ $0.filePath }
        let newFileNames = Set(fileNames).subtract(fileList)

        if !newFileNames.isEmpty {
            try appendToFileList(newFileNames)
        }

        try dataset.write(fileNames, fileSpace: filespace)
    }

    func appendToFileList(files: Set<String>) throws {
        guard let dataset = file.openStringDataset(FeatureDatabase.fileListDatasetName) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileListDatasetName) dataset")
        }

        fileList.unionInPlace(files)

        let currentSize = dataset.extent[0]
        dataset.extent[0] += files.count

        let filespace = dataset.space
        filespace.select(start: [currentSize], stride: nil, count: [files.count], block: nil)


        try dataset.write(Array(files), fileSpace: filespace)
    }

    public func shuffle(var chunkSize chunkSize: Int, passes: Int = 1, progress: (Double -> Void)? = nil) throws {
        let exampleCount = labelTables[0].rowCount
        chunkSize = min(chunkSize, exampleCount/2)
        let shuffleCount = passes * exampleCount / chunkSize
        for i in 0..<shuffleCount {
            let start1 = i * chunkSize % (exampleCount - chunkSize + 1)
            let start2 = randomInRange(0...exampleCount - chunkSize)
            let indices = (0..<2*chunkSize).shuffle()

            shuffleDoubleTables(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)
            shuffleOffsets(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)
            try shuffleStringTables(chunkSize: chunkSize, start1: start1, start2: start2, indices: indices)

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

    func shuffleOffsets(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) {
        let table = IntTable(file: file, name: FeatureDatabase.offsetDatasetName, rowSize: 1)
        let data = ValueArray<Int>(capacity: 2 * chunkSize)

        let count1 = try! table.readFromRow(start1, count: chunkSize, into: data.mutablePointer)
        assert(count1 == chunkSize)

        let count2 = try! table.readFromRow(start2, count: chunkSize, into: data.mutablePointer + chunkSize * table.rowSize)
        assert(count2 == chunkSize)

        data.count = 2 * chunkSize
        for i in 0..<2 * chunkSize {
            let index = indices[i]
            if index != i {
                swap(&data[i], &data[index])
            }
        }

        try! table.overwriteFromRow(start1, with: data[0..<chunkSize])
        try! table.overwriteFromRow(start2, with: data[chunkSize..<2 * chunkSize])
    }

    func shuffleStringTables(chunkSize chunkSize: Int, start1: Int, start2: Int, indices: [Int]) throws {
        guard let dataset = file.openStringDataset(FeatureDatabase.fileNameDatasetName) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileNameDatasetName) dataset")
        }

        var strings1 = dataset[start1..<start1 + chunkSize]
        var strings2 = dataset[start2..<start2 + chunkSize]
        var strings = strings1 + strings2

        for i in 0..<2*chunkSize {
            let index = indices[i]
            if index != i {
                swap(&strings[i], &strings[index])
            }
        }

        strings1 = [String](strings.dropLast(chunkSize))
        strings2 = [String](strings.dropFirst(chunkSize))
        try dataset.write(strings1, to: [start1..<start1 + chunkSize])
        try dataset.write(strings2, to: [start2..<start2 + chunkSize])
    }
}
