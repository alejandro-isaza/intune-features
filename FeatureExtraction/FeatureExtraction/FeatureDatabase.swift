//  Copyright © 2015 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public class FeatureDatabase {
    public enum Error: ErrorType {
        case DatasetNotFound
        case DatasetNotCompatible
    }

    public static let fileListDatasetName = "file_list"

    public static let fileIdDatasetName = "file_id"
    public static let offsetDatasetName = "offset"
    public static let sequenceLengthDatasetName = "sequence_length"
    public static let eventOffsetDatasetName = "event_offset"
    public static let eventDurationDatasetName = "event_duration"
    public static let eventNoteDatasetName = "event_note"
    public static let eventVelocityDatasetName = "event_velocity"

    public static let featuresLengthDatasetName = "features_length"
    public static let featureOnsetValuesDatasetName = "features_onset_values"
    public static let featurePolyphonyValuesDatasetName = "features_polyphony_values"
    public static let peakLocationsDatasetName = "peak_locations"
    public static let peakHeightsDatasetName = "peak_heights"
    public static let spectrumDatasetName = "spectrum"
    public static let spectrumFluxDatasetName = "spectrum_flux"

    let chunkSize: Int
    let filePath: String
    let file: File

    public internal(set) var filePaths = [String]()
    public internal(set) var fileIdsByPath = [String: Int]()
    public internal(set) var filePathsById = [Int: String]()
    
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

    public func flush() {
        file.flush()
    }
    
    func load() {
        filePaths = readFileList()
        for (index, path) in filePaths.enumerate() {
            fileIdsByPath[path] = index
            filePathsById[index] = path
        }
    }

    func readFileList() -> [String] {
        let dataset = file.openStringDataset(FeatureDatabase.fileListDatasetName)!
        return dataset[0..]
    }

    func getFileId(path: String) throws -> Int {
        if let id = fileIdsByPath[path] {
            return id
        }

        guard let dataset = file.openStringDataset(FeatureDatabase.fileListDatasetName) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.fileListDatasetName) dataset")
        }

        let id = filePaths.count
        filePaths.append(path)
        fileIdsByPath[path] = id
        filePathsById[id] = path

        try dataset.append([path], dimensions: [1])
        return id
    }
}


// MARK: Sequence Writing

public extension FeatureDatabase {
    public func create() {
        let chunkSize = 1024
        let eventChunkSize = 16
        let featureChunkSize = 32

        let space = Dataspace(dims: [0], maxDims: [-1])
        file.createStringDataset(FeatureDatabase.fileListDatasetName, dataspace: space, chunkDimensions: [32])!

        file.createIntDataset(FeatureDatabase.offsetDatasetName,
            dataspace: Dataspace(dims: [0], maxDims: [-1]),
            chunkDimensions: [chunkSize])

        file.createIntDataset(FeatureDatabase.fileIdDatasetName,
            dataspace: Dataspace(dims: [0], maxDims: [-1]),
            chunkDimensions: [chunkSize])

        file.createIntDataset(FeatureDatabase.sequenceLengthDatasetName,
            dataspace: Dataspace(dims: [0], maxDims: [-1]),
            chunkDimensions: [chunkSize])

        file.createIntDataset(FeatureDatabase.featuresLengthDatasetName,
            dataspace: Dataspace(dims: [0], maxDims: [-1]),
            chunkDimensions: [chunkSize])

        file.createIntDataset(FeatureDatabase.eventOffsetDatasetName,
            dataspace: Dataspace(dims: [0, 0], maxDims: [-1, -1]),
            chunkDimensions: [chunkSize, eventChunkSize])

        file.createDoubleDataset(FeatureDatabase.featureOnsetValuesDatasetName,
            dataspace: Dataspace(dims: [0, 0], maxDims: [-1, -1]),
            chunkDimensions: [chunkSize, featureChunkSize])

        file.createDoubleDataset(FeatureDatabase.featurePolyphonyValuesDatasetName,
            dataspace: Dataspace(dims: [0, 0], maxDims: [-1, -1]),
            chunkDimensions: [chunkSize, featureChunkSize])

        let labelSize = Note.noteCount
        file.createDoubleDataset(FeatureDatabase.eventNoteDatasetName,
            dataspace: Dataspace(dims: [0, 0, labelSize], maxDims: [-1, -1, labelSize]),
            chunkDimensions: [chunkSize, eventChunkSize, labelSize])

        file.createDoubleDataset(FeatureDatabase.eventVelocityDatasetName,
            dataspace: Dataspace(dims: [0, 0, labelSize], maxDims: [-1, -1, labelSize]),
            chunkDimensions: [chunkSize, eventChunkSize, labelSize])

        let featureSize = FeatureBuilder.bandNotes.count
        file.createDoubleDataset(FeatureDatabase.spectrumDatasetName,
            dataspace: Dataspace(dims: [0, 0, featureSize], maxDims: [-1, -1, featureSize]),
            chunkDimensions: [chunkSize, featureChunkSize, featureSize])

        file.createDoubleDataset(FeatureDatabase.spectrumFluxDatasetName,
            dataspace: Dataspace(dims: [0, 0, featureSize], maxDims: [-1, -1, featureSize]),
            chunkDimensions: [chunkSize, featureChunkSize, featureSize])

        file.createDoubleDataset(FeatureDatabase.peakHeightsDatasetName,
            dataspace: Dataspace(dims: [0, 0, featureSize], maxDims: [-1, -1, featureSize]),
            chunkDimensions: [chunkSize, featureChunkSize, featureSize])

        file.createDoubleDataset(FeatureDatabase.peakLocationsDatasetName,
            dataspace: Dataspace(dims: [0, 0, featureSize], maxDims: [-1, -1, featureSize]),
            chunkDimensions: [chunkSize, featureChunkSize, featureSize])
    }

    public func appendSequence(sequence: Sequence) throws {
        try writeOffset(sequence)
        try writeFile(sequence)
        try writeEvents(sequence)
        try writeFeatures(sequence)
    }

    func writeOffset(sequence: Sequence) throws {
        guard let offsetDataset = file.openIntDataset(FeatureDatabase.offsetDatasetName) else {
            throw Error.DatasetNotFound
        }
        try offsetDataset.append([sequence.startOffset], dimensions: [1])
    }

    func writeFile(sequence: Sequence) throws {
        guard let fileDataset = file.openIntDataset(FeatureDatabase.fileIdDatasetName) else {
            throw Error.DatasetNotFound
        }
        let id = try getFileId(sequence.filePath)
        try fileDataset.append([id], dimensions: [1])
    }

    func writeEvents(sequence: Sequence) throws {
        guard let lengthDataset = file.openIntDataset(FeatureDatabase.sequenceLengthDatasetName) else {
            throw Error.DatasetNotFound
        }
        try lengthDataset.append([sequence.events.count], dimensions: [1])

        try writeEventOffsets(sequence)
        try writeEventNotes(sequence)
        try writeEventVelocities(sequence)
    }

    func writeEventOffsets(sequence: Sequence) throws {
        guard let eventOffsetDataset = file.openIntDataset(FeatureDatabase.eventOffsetDatasetName) else {
            throw Error.DatasetNotFound
        }

        let eventOffsets = sequence.events.map({ $0.offset })
        try eventOffsetDataset.append(eventOffsets, dimensions: [1, eventOffsets.count])
    }

    func writeEventNotes(sequence: Sequence) throws {
        guard let eventNoteDataset = file.openDoubleDataset(FeatureDatabase.eventNoteDatasetName) else {
            throw Error.DatasetNotFound
        }

        var noteValues = [Real](count: Note.noteCount * sequence.events.count, repeatedValue: 0.0)
        for event in sequence.events {
            for note in event.notes {
                let index = note.midiNoteNumber - Note.representableRange.startIndex
                if index >= 0 && index < Note.noteCount {
                    noteValues[note.midiNoteNumber - Note.representableRange.startIndex] = 1.0
                }
            }
        }
        try eventNoteDataset.append(noteValues, dimensions: [1, sequence.events.count, Note.noteCount])
    }

    func writeEventVelocities(sequence: Sequence) throws {
        guard let eventVelocitiesDataset = file.openDoubleDataset(FeatureDatabase.eventVelocityDatasetName) else {
            throw Error.DatasetNotFound
        }

        var velocities = [Real](count: Note.noteCount * sequence.events.count, repeatedValue: 0.0)
        for (eventIndex, event) in sequence.events.enumerate() {
            for (noteIndex, note) in event.notes.enumerate() {
                let index = note.midiNoteNumber - Note.representableRange.startIndex
                if index >= 0 && index < Note.noteCount {
                    velocities[eventIndex * Note.noteCount + index] = event.velocities[noteIndex]
                }
            }
        }
        try eventVelocitiesDataset.append(velocities, dimensions: [1, sequence.events.count, Note.noteCount])
    }

    func writeFeatures(sequence: Sequence) throws {
        precondition(sequence.features.count == sequence.featureOnsetValues.count)
        precondition(sequence.features.count == sequence.featurePolyphonyValues.count)
        
        guard let lengthDataset = file.openIntDataset(FeatureDatabase.featuresLengthDatasetName) else {
            throw Error.DatasetNotFound
        }
        try lengthDataset.append([sequence.features.count], dimensions: [1])

        guard let featureOnsetValuesDataset = file.openDoubleDataset(FeatureDatabase.featureOnsetValuesDatasetName) else {
            throw Error.DatasetNotFound
        }
        try featureOnsetValuesDataset.append(sequence.featureOnsetValues, dimensions: [1, sequence.featureOnsetValues.count])

        guard let featurePolyphonyValuesDataset = file.openDoubleDataset(FeatureDatabase.featurePolyphonyValuesDatasetName) else {
            throw Error.DatasetNotFound
        }
        try featurePolyphonyValuesDataset.append(sequence.featurePolyphonyValues, dimensions: [1, sequence.featurePolyphonyValues.count])
        
        try writeSpectrum(sequence)
        try writeSpectralFlux(sequence)
        try writePeakHeights(sequence)
        try writePeakLocations(sequence)
    }

    func writeSpectrum(sequence: Sequence) throws {
        guard let spectrumDataset = file.openDoubleDataset(FeatureDatabase.spectrumDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * sequence.features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in sequence.features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.spectrum[i]
            }
        }
        try spectrumDataset.append(data, dimensions: [1, sequence.features.count, featureSize])
    }

    func writeSpectralFlux(sequence: Sequence) throws {
        guard let spectralFluxDataset = file.openDoubleDataset(FeatureDatabase.spectrumFluxDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * sequence.features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in sequence.features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.spectralFlux[i]
            }
        }
        try spectralFluxDataset.append(data, dimensions: [1, sequence.features.count, featureSize])
    }

    func writePeakHeights(sequence: Sequence) throws {
        guard let peakHeightsDataset = file.openDoubleDataset(FeatureDatabase.peakHeightsDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * sequence.features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in sequence.features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.peakHeights[i]
            }
        }
        try peakHeightsDataset.append(data, dimensions: [1, sequence.features.count, featureSize])
    }

    func writePeakLocations(sequence: Sequence) throws {
        guard let peakLocationsDataset = file.openDoubleDataset(FeatureDatabase.peakLocationsDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        var data = [Real](count: featureSize * sequence.features.count, repeatedValue: 0.0)
        for (featureIndex, feature) in sequence.features.enumerate() {
            for i in 0..<featureSize {
                data[featureIndex * featureSize + i] = feature.peakLocations[i]
            }
        }
        try peakLocationsDataset.append(data, dimensions: [1, sequence.features.count, featureSize])
    }
}


// MARK: Sequence Reading

public extension FeatureDatabase {
    public func readSequenceAtIndex(index: Int) throws -> Sequence {
        let sequence = Sequence()
        try readOffset(sequence, index: index)
        try readFileName(sequence, index: index)
        try readEvents(sequence, index: index)
        try readFeatures(sequence, index: index)
        return sequence
    }

    func readOffset(sequence: Sequence, index: Int) throws {
        guard let offsetDataset = file.openIntDataset(FeatureDatabase.offsetDatasetName) else {
            throw Error.DatasetNotFound
        }
        sequence.startOffset = try offsetDataset.read([index]).first!
    }

    func readFileName(sequence: Sequence, index: Int) throws {
        guard let fileDataset = file.openIntDataset(FeatureDatabase.fileIdDatasetName) else {
            throw Error.DatasetNotFound
        }
        let id = try fileDataset.read([index]).first!
        sequence.filePath = filePathsById[id] ?? ""
    }

    func readEvents(sequence: Sequence, index: Int) throws {
        guard let sequenceLengthDataset = file.openIntDataset(FeatureDatabase.sequenceLengthDatasetName) else {
            throw Error.DatasetNotFound
        }
        let length = try sequenceLengthDataset.read([index]).first!

        sequence.events.removeAll()
        for _ in 0..<length {
            sequence.events.append(Sequence.Event())
        }

        try readEventOffsets(sequence, index: index, length: length)
        try readEventNotes(sequence, index: index, length: length)
        try readEventVelocities(sequence, index: index, length: length)
    }

    func readEventOffsets(sequence: Sequence, index: Int, length: Int) throws {
        guard let eventOffsetDataset = file.openIntDataset(FeatureDatabase.eventOffsetDatasetName) else {
            throw Error.DatasetNotFound
        }

        let offsets = try eventOffsetDataset.read([index, 0..<length])
        for (i, event) in sequence.events.enumerate() {
            event.offset = offsets[i]
        }
    }

    func readEventNotes(sequence: Sequence, index: Int, length: Int) throws {
        guard let eventNoteDataset = file.openDoubleDataset(FeatureDatabase.eventNoteDatasetName) else {
            throw Error.DatasetNotFound
        }

        let noteValues = try eventNoteDataset.read([index, 0..<length, 0..<Note.noteCount])
        for (index, event) in sequence.events.enumerate() {
            event.notes = notesFromVector(noteValues[index * Note.noteCount..<(index + 1) * Note.noteCount])
        }
    }

    func readEventVelocities(sequence: Sequence, index: Int, length: Int) throws {
        guard let eventVelocitiesDataset = file.openDoubleDataset(FeatureDatabase.eventVelocityDatasetName) else {
            throw Error.DatasetNotFound
        }

        let velocities = try eventVelocitiesDataset.read([index, 0..<length, 0..<Note.noteCount])
        for (eventIndex, event) in sequence.events.enumerate() {
            event.velocities = [Double](count: event.notes.count, repeatedValue: 0.0)
            for (noteIndex, note) in event.notes.enumerate() {
                event.velocities[noteIndex] = velocities[eventIndex * Note.noteCount + note.midiNoteNumber - Note.representableRange.startIndex]
            }
        }
    }

    func readFeatures(sequence: Sequence, index: Int) throws {
        guard let featuresLengthDataset = file.openIntDataset(FeatureDatabase.featuresLengthDatasetName) else {
            throw Error.DatasetNotFound
        }
        let length = try featuresLengthDataset.read([index]).first!

        guard let featureOnsetValuesDataset = file.openDoubleDataset(FeatureDatabase.featureOnsetValuesDatasetName) else {
            throw Error.DatasetNotFound
        }
        sequence.featureOnsetValues = try featureOnsetValuesDataset.read([index, 0..<length])

        guard let featurePolyphonyValuesDataset = file.openDoubleDataset(FeatureDatabase.featurePolyphonyValuesDatasetName) else {
            throw Error.DatasetNotFound
        }
        sequence.featurePolyphonyValues = try featurePolyphonyValuesDataset.read([index, 0..<length])

        sequence.features.removeAll()
        for _ in 0..<length {
            sequence.features.append(Feature())
        }

        try readSpectrum(sequence, index: index, length: length)
        try readSpectralFlux(sequence, index: index, length: length)
        try readPeakHeights(sequence, index: index, length: length)
        try readPeakLocations(sequence, index: index, length: length)
    }

    func readSpectrum(sequence: Sequence, index: Int, length: Int) throws {
        guard let spectrumDataset = file.openDoubleDataset(FeatureDatabase.spectrumDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        let spectrums = try spectrumDataset.read([index, 0..<length, 0..<featureSize])
        for (featureIndex, feature) in sequence.features.enumerate() {
            spectrums.withUnsafeBufferPointer { pointer in
                let offsetPointer = UnsafeMutablePointer<Double>(pointer.baseAddress + featureIndex * featureSize)
                feature.spectrum.mutablePointer.assignFrom(offsetPointer, count: featureSize)
            }
        }
    }

    func readSpectralFlux(sequence: Sequence, index: Int, length: Int) throws {
        guard let spectralFluxDataset = file.openDoubleDataset(FeatureDatabase.spectrumFluxDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        let spectrums = try spectralFluxDataset.read([index, 0..<length, 0..<featureSize])
        for (featureIndex, feature) in sequence.features.enumerate() {
            spectrums.withUnsafeBufferPointer { pointer in
                let offsetPointer = UnsafeMutablePointer<Double>(pointer.baseAddress + featureIndex * featureSize)
                feature.spectralFlux.mutablePointer.assignFrom(offsetPointer, count: featureSize)
            }
        }
    }

    func readPeakHeights(sequence: Sequence, index: Int, length: Int) throws {
        guard let peakHeightsDataset = file.openDoubleDataset(FeatureDatabase.peakHeightsDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        let spectrums = try peakHeightsDataset.read([index, 0..<length, 0..<featureSize])
        for (featureIndex, feature) in sequence.features.enumerate() {
            spectrums.withUnsafeBufferPointer { pointer in
                let offsetPointer = UnsafeMutablePointer<Double>(pointer.baseAddress + featureIndex * featureSize)
                feature.peakHeights.mutablePointer.assignFrom(offsetPointer, count: featureSize)
            }
        }
    }

    func readPeakLocations(sequence: Sequence, index: Int, length: Int) throws {
        guard let peakLocationsDataset = file.openDoubleDataset(FeatureDatabase.peakLocationsDatasetName) else {
            throw Error.DatasetNotFound
        }

        let featureSize = FeatureBuilder.bandNotes.count
        let spectrums = try peakLocationsDataset.read([index, 0..<length, 0..<featureSize])
        for (featureIndex, feature) in sequence.features.enumerate() {
            spectrums.withUnsafeBufferPointer { pointer in
                let offsetPointer = UnsafeMutablePointer<Double>(pointer.baseAddress + featureIndex * featureSize)
                feature.peakLocations.mutablePointer.assignFrom(offsetPointer, count: featureSize)
            }
        }
    }
}
