//  Copyright © 2015 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public class FeatureDatabase {
    public static let fileListDatasetName = "file_list"
    public static let fileNameDatasetName = "file_name"
    public static let offsetDatasetName = "offset"
    public static let sequenceLengthDatasetName = "sequence_length"
    public static let eventOffsetDatasetName = "event_offset"
    public static let eventDurationDatasetName = "event_duration"
    public static let eventNoteDatasetName = "event_note"
    public static let eventVelocityDatasetName = "event_velocity"

    public static let peakLocationsDatasetName = "peak_locations"
    public static let peakHeightsDatasetName = "peak_heights"
    public static let spectrumDatasetName = "spectrum"
    public static let spectrumFluxDatasetName = "spectrum_flux"

    let chunkSize: Int
    let filePath: String
    let file: File

    struct StringTable {
        var name: String
        var data: [String]
    }

    public internal(set) var fileList = Set<String>()
    public internal(set) var fileNames = [String]()
    
    public var sequenceCount: Int {
        guard let offsetDataset = file.openIntDataset(FeatureDatabase.offsetDatasetName) else {
            return 0
        }
        return offsetDataset.extent[0]
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
    }

    func create() {
        let space = Dataspace(dims: [0], maxDims: [-1])
        file.createStringDataset(FeatureDatabase.fileListDatasetName, dataspace: space, chunkDimensions: [32])!
        Sequence.initializeDatabaseInFile(file)
    }

    func load() {
        guard let dataset = file.openStringDataset(FeatureDatabase.fileNameDatasetName) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileNameDatasetName) dataset")
        }
        precondition(dataset.space.dims.count == 1, "Existing dataset '\(FeatureDatabase.fileNameDatasetName)' is of the wrong size")

        fileList = readFileList()
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

    func appendToFileList(files: Set<String>) throws {
        guard let dataset = file.openStringDataset(FeatureDatabase.fileListDatasetName) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileListDatasetName) dataset")
        }

        let newFiles = files.subtract(fileList)
        if newFiles.isEmpty {
            return
        }
        fileList.unionInPlace(newFiles)

        let currentSize = dataset.extent[0]
        dataset.extent[0] += newFiles.count

        let filespace = dataset.space
        filespace.select(start: [currentSize], stride: nil, count: [newFiles.count], block: nil)

        try dataset.write(Array(newFiles), fileSpace: filespace)
    }

    public func appendSequence(sequence: Sequence) throws {
        try sequence.writeToFile(file)
    }

    public func readSequenceAtIndex(index: Int) throws -> Sequence {
        let sequence = Sequence()
        try sequence.readFromFile(file, row: index)
        return sequence
    }
}


// MARK: Sequence Writing

public extension Sequence {
    public static func initializeDatabaseInFile(file: File) {
        let chunkSize = 1024
        let sequenceChunkSize = 10

        file.createIntDataset(FeatureDatabase.offsetDatasetName,
            dataspace: Dataspace(dims: [0], maxDims: [-1]),
            chunkDimensions: [chunkSize])

        file.createStringDataset(FeatureDatabase.fileNameDatasetName,
            dataspace: Dataspace(dims: [0], maxDims: [-1]),
            chunkDimensions: [chunkSize])

        file.createIntDataset(FeatureDatabase.sequenceLengthDatasetName,
            dataspace: Dataspace(dims: [0], maxDims: [-1]),
            chunkDimensions: [chunkSize])

        file.createIntDataset(FeatureDatabase.eventOffsetDatasetName,
            dataspace: Dataspace(dims: [0, 0], maxDims: [-1, -1]),
            chunkDimensions: [chunkSize, sequenceChunkSize])

        let labelSize = Note.noteCount
        file.createDoubleDataset(FeatureDatabase.eventNoteDatasetName,
            dataspace: Dataspace(dims: [0, 0, labelSize], maxDims: [-1, -1, labelSize]),
            chunkDimensions: [chunkSize, sequenceChunkSize, labelSize])

        file.createDoubleDataset(FeatureDatabase.eventVelocityDatasetName,
            dataspace: Dataspace(dims: [0, 0, labelSize], maxDims: [-1, -1, labelSize]),
            chunkDimensions: [chunkSize, sequenceChunkSize, labelSize])

        let featureSize = FeatureBuilder.bandNotes.count
        file.createDoubleDataset(FeatureDatabase.spectrumDatasetName,
            dataspace: Dataspace(dims: [0, 0, featureSize], maxDims: [-1, -1, featureSize]),
            chunkDimensions: [chunkSize, sequenceChunkSize, featureSize])

        file.createDoubleDataset(FeatureDatabase.spectrumFluxDatasetName,
            dataspace: Dataspace(dims: [0, 0, featureSize], maxDims: [-1, -1, featureSize]),
            chunkDimensions: [chunkSize, sequenceChunkSize, featureSize])

        file.createDoubleDataset(FeatureDatabase.peakHeightsDatasetName,
            dataspace: Dataspace(dims: [0, 0, featureSize], maxDims: [-1, -1, featureSize]),
            chunkDimensions: [chunkSize, sequenceChunkSize, featureSize])

        file.createDoubleDataset(FeatureDatabase.peakLocationsDatasetName,
            dataspace: Dataspace(dims: [0, 0, featureSize], maxDims: [-1, -1, featureSize]),
            chunkDimensions: [chunkSize, sequenceChunkSize, featureSize])
    }

    public func writeToFile(file: File) throws {
        try writeOffsetToFile(file)
        try writeFileNameToFile(file)
        try writeEventsToFile(file)
        try writeFeaturesToFile(file)
    }

    func writeOffsetToFile(file: File) throws {
        guard let offsetDataset = file.openIntDataset(FeatureDatabase.offsetDatasetName) else {
            throw Error.DatasetNotFound
        }
        try offsetDataset.append([startOffset], dimensions: [1])
    }

    func writeFileNameToFile(file: File) throws {
        guard let fileDataset = file.openStringDataset(FeatureDatabase.fileNameDatasetName) else {
            throw Error.DatasetNotFound
        }
        try fileDataset.append([filePath], dimensions: [1])
    }

    func writeEventsToFile(file: File) throws {
        guard let lengthDataset = file.openIntDataset(FeatureDatabase.sequenceLengthDatasetName) else {
            throw Error.DatasetNotFound
        }
        try lengthDataset.append([events.count], dimensions: [1])

        try writeEventOffsetsToFile(file)
        try writeEventNotesToFile(file)
        try writeEventVelocitiesToFile(file)
    }

    func writeEventOffsetsToFile(file: File) throws {
        guard let eventOffsetDataset = file.openIntDataset(FeatureDatabase.eventOffsetDatasetName) else {
            throw Error.DatasetNotFound
        }

        let eventOffsets = events.map({ $0.offset })
        try eventOffsetDataset.append(eventOffsets, dimensions: [1, eventOffsets.count])
    }

    func writeEventNotesToFile(file: File) throws {
        guard let eventNoteDataset = file.openDoubleDataset(FeatureDatabase.eventNoteDatasetName) else {
            throw Error.DatasetNotFound
        }

        var noteValues = [Real](count: Note.noteCount * events.count, repeatedValue: 0.0)
        for event in events {
            for note in event.notes {
                noteValues[note.midiNoteNumber - Note.representableRange.startIndex] = 1.0
            }
        }
        try eventNoteDataset.append(noteValues, dimensions: [1, events.count, Note.noteCount])
    }

    func writeEventVelocitiesToFile(file: File) throws {
        guard let eventVelocitiesDataset = file.openDoubleDataset(FeatureDatabase.eventVelocityDatasetName) else {
            throw Error.DatasetNotFound
        }

        var velocities = [Real](count: Note.noteCount * events.count, repeatedValue: 0.0)
        for (eventIndex, event) in events.enumerate() {
            for (noteIndex, note) in event.notes.enumerate() {
                velocities[eventIndex * Note.noteCount + note.midiNoteNumber - Note.representableRange.startIndex] = event.velocities[noteIndex]
            }
        }
        try eventVelocitiesDataset.append(velocities, dimensions: [1, events.count, Note.noteCount])
    }

    func writeFeaturesToFile(file: File) throws {
        try writeSpectrumToFile(file)
        try writeSpectralFluxToFile(file)
        try writePeakHeights(file)
        try writePeakLocations(file)
    }

    func writeSpectrumToFile(file: File) throws {
        guard let spectrumDataset = file.openDoubleDataset(FeatureDatabase.spectrumDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.spectrum[i]
            }
        }
        try spectrumDataset.append(data, dimensions: [1, features.count, featureSize])
    }

    func writeSpectralFluxToFile(file: File) throws {
        guard let spectralFluxDataset = file.openDoubleDataset(FeatureDatabase.spectrumFluxDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.spectralFlux[i]
            }
        }
        try spectralFluxDataset.append(data, dimensions: [1, features.count, featureSize])
    }

    func writePeakHeights(file: File) throws {
        guard let peakHeightsDataset = file.openDoubleDataset(FeatureDatabase.peakHeightsDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.peakHeights[i]
            }
        }
        try peakHeightsDataset.append(data, dimensions: [1, features.count, featureSize])
    }

    func writePeakLocations(file: File) throws {
        guard let peakLocationsDataset = file.openDoubleDataset(FeatureDatabase.peakLocationsDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.peakLocations[i]
            }
        }
        try peakLocationsDataset.append(data, dimensions: [1, features.count, featureSize])
    }
}


// MARK: Sequence Reading

public extension Sequence {
    public func readFromFile(file: File, row: Int) throws {
        try readOffsetFromFile(file, row: row)
        try readFileNameFromFile(file, row: row)
        try readEventsFromFile(file, row: row)
        try readFeaturesFromFile(file, row: row)
    }

    func readOffsetFromFile(file: File, row: Int) throws {
        guard let offsetDataset = file.openIntDataset(FeatureDatabase.offsetDatasetName) else {
            throw Error.DatasetNotFound
        }
        startOffset = try offsetDataset.read([row]).first!
    }

    func readFileNameFromFile(file: File, row: Int) throws {
        guard let fileDataset = file.openStringDataset(FeatureDatabase.fileNameDatasetName) else {
            throw Error.DatasetNotFound
        }
        filePath = try fileDataset.read([row]).first!
    }

    func readEventsFromFile(file: File, row: Int) throws {
        guard let sequenceLengthDataset = file.openIntDataset(FeatureDatabase.sequenceLengthDatasetName) else {
            throw Error.DatasetNotFound
        }
        let length = try sequenceLengthDataset.read([row]).first!

        events.removeAll()
        for _ in 0..<length {
            events.append(Event())
        }

        try readEventOffsetsFromFile(file, row: row, length: length)
        try readEventNotesFromFile(file, row: row, length: length)
        try readEventVelocitiesFromFile(file, row: row, length: length)
    }

    func readEventOffsetsFromFile(file: File, row: Int, length: Int) throws {
        guard let eventOffsetDataset = file.openIntDataset(FeatureDatabase.eventOffsetDatasetName) else {
            throw Error.DatasetNotFound
        }

        let offsets = try eventOffsetDataset.read([row, 0..<length])
        for (i, event) in events.enumerate() {
            event.offset = offsets[i]
        }
    }

    func readEventNotesFromFile(file: File, row: Int, length: Int) throws {
        guard let eventNoteDataset = file.openDoubleDataset(FeatureDatabase.eventNoteDatasetName) else {
            throw Error.DatasetNotFound
        }

        let noteValues = try eventNoteDataset.read([row, 0..<length, 0..<Note.noteCount])
        for (index, event) in events.enumerate() {
            event.notes = notesFromVector(noteValues[index * Note.noteCount..<(index + 1) * Note.noteCount])
        }
    }

    func readEventVelocitiesFromFile(file: File, row: Int, length: Int) throws {
        guard let eventVelocitiesDataset = file.openDoubleDataset(FeatureDatabase.eventVelocityDatasetName) else {
            throw Error.DatasetNotFound
        }

        let velocities = try eventVelocitiesDataset.read([row, 0..<length, 0..<Note.noteCount])
        for (eventIndex, event) in events.enumerate() {
            event.velocities = [Double](count: event.notes.count, repeatedValue: 0.0)
            for (noteIndex, note) in event.notes.enumerate() {
                event.velocities[noteIndex] = velocities[eventIndex * Note.noteCount + note.midiNoteNumber - Note.representableRange.startIndex]
            }
        }
    }

    func readFeaturesFromFile(file: File, row: Int) throws {
        try readSpectrumFromFile(file, row: row)
        try readSpectralFluxFromFile(file, row: row)
        try readPeakHeightsFromFile(file, row: row)
        try readPeakLocationsFromFile(file, row: row)
    }

    func readSpectrumFromFile(file: File, row: Int) throws {
        guard let spectrumDataset = file.openDoubleDataset(FeatureDatabase.spectrumDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.spectrum[i]
            }
        }
        try spectrumDataset.append(data, dimensions: [1, features.count, featureSize])
    }

    func readSpectralFluxFromFile(file: File, row: Int) throws {
        guard let spectralFluxDataset = file.openDoubleDataset(FeatureDatabase.spectrumFluxDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.spectralFlux[i]
            }
        }
        try spectralFluxDataset.append(data, dimensions: [1, features.count, featureSize])
    }

    func readPeakHeightsFromFile(file: File, row: Int) throws {
        guard let peakHeightsDataset = file.openDoubleDataset(FeatureDatabase.peakHeightsDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.peakHeights[i]
            }
        }
        try peakHeightsDataset.append(data, dimensions: [1, features.count, featureSize])
    }

    func readPeakLocationsFromFile(file: File, row: Int) throws {
        guard let peakLocationsDataset = file.openDoubleDataset(FeatureDatabase.peakLocationsDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.peakLocations[i]
            }
        }
        try peakLocationsDataset.append(data, dimensions: [1, features.count, featureSize])
    }
}
