//  Copyright © 2015 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public class FeatureDatabase {
    public enum Error: ErrorType {
        case DatasetNotFound
        case DatasetNotCompatible
    }

    public let chunkSize: Int
    let filePath: String
    let file: File

    public init(filePath: String, chunkSize: Int = 1024) {
        self.filePath = filePath
        self.chunkSize = chunkSize

        file = File.create(filePath, mode: .Truncate)!
        file.createGroup("events")
        file.createGroup("labels")
        file.createGroup("features")
        
        for table in Table.allValues {
            table.createInFile(file)
        }
    }

    public func flush() {
        file.flush()
    }
}


// MARK: Events

public extension FeatureDatabase {
    public func writeEvent(event: Event) throws {
        try writeEventStart(event)
        try writeEventDuration(event)
        try writeEventNote(event)
        try writeEventVelocity(event)

    }

    func writeEventStart(event: Event) throws {
        guard let dataset = file.openIntDataset(Table.eventsStart.rawValue) else {
            throw Error.DatasetNotFound
        }
        try dataset.append([event.start], dimensions: [1])
    }

    func writeEventDuration(event: Event) throws {
        guard let dataset = file.openIntDataset(Table.eventsDuration.rawValue) else {
            throw Error.DatasetNotFound
        }
        try dataset.append([event.duration], dimensions: [1])
    }

    func writeEventNote(event: Event) throws {
        guard let dataset = file.openIntDataset(Table.eventsNote.rawValue) else {
            throw Error.DatasetNotFound
        }
        try dataset.append([event.note.midiNoteNumber], dimensions: [1])
    }

    func writeEventVelocity(event: Event) throws {
        guard let dataset = file.openFloatDataset(Table.eventsVelocity.rawValue) else {
            throw Error.DatasetNotFound
        }
        try dataset.append([event.velocity], dimensions: [1])
    }

    public func readEventAtIndex(index: Int) throws -> Event {
        var event = Event()
        event.start = try readEventStartAtIndex(index)
        event.duration = try readEventDurationAtIndex(index)
        event.note = try readEventNoteAtIndex(index)
        event.velocity = try readEventVelocityAtIndex(index)
        return event
    }

    func readEventStartAtIndex(index: Int) throws -> Int {
        guard let dataset = file.openIntDataset(Table.eventsStart.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index]).first!
    }

    func readEventDurationAtIndex(index: Int) throws -> Int {
        guard let dataset = file.openIntDataset(Table.eventsDuration.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index]).first!
    }

    func readEventNoteAtIndex(index: Int) throws -> Note {
        guard let dataset = file.openIntDataset(Table.eventsNote.rawValue) else {
            throw Error.DatasetNotFound
        }
        return Note(midiNoteNumber: try dataset.read([index]).first!)
    }

    func readEventVelocityAtIndex(index: Int) throws -> Float {
        guard let dataset = file.openFloatDataset(Table.eventsVelocity.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index]).first!
    }
}


// MARK: Labels

public extension FeatureDatabase {
    public func writeLabels(labels: [Label]) throws {
        try writeLabelOnsets(labels)
        try writeLabelPolyphonies(labels)
        try writeLabelNotes(labels)
    }

    func writeLabelOnsets(labels: [Label]) throws {
        guard let dataset = file.openFloatDataset(Table.labelsOnset.rawValue) else {
            throw Error.DatasetNotFound
        }
        let onsets = labels.map({ $0.onset })
        try dataset.append(onsets, dimensions: [onsets.count])
    }

    func writeLabelPolyphonies(labels: [Label]) throws {
        guard let dataset = file.openFloatDataset(Table.labelsPolyphony.rawValue) else {
            throw Error.DatasetNotFound
        }
        let polyphonies = labels.map({ $0.polyphony })
        try dataset.append(polyphonies, dimensions: [polyphonies.count])
    }

    func writeLabelNotes(labels: [Label]) throws {
        guard let dataset = file.openFloatDataset(Table.labelsNotes.rawValue) else {
            throw Error.DatasetNotFound
        }
        let notes = labels.flatMap({ $0.notes })
        try dataset.append(notes, dimensions: [labels.count, Note.noteCount])
    }

    public func readLabelAtIndex(index: Int) throws -> Label {
        var label = Label()
        label.onset = try readLabelOnsetAtIndex(index)
        label.polyphony = try readLabelPolyphonyAtIndex(index)
        label.notes = try readLabelNotesAtIndex(index)
        return label
    }

    func readLabelOnsetAtIndex(index: Int) throws -> Float {
        guard let dataset = file.openFloatDataset(Table.labelsOnset.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index]).first!
    }

    func readLabelPolyphonyAtIndex(index: Int) throws -> Float {
        guard let dataset = file.openFloatDataset(Table.labelsPolyphony.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index]).first!
    }

    func readLabelNotesAtIndex(index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.labelsNotes.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index, 0..])
    }
}


// MARK: Feature Writing

public extension FeatureDatabase {
    func writeFeatures(features: [Feature]) throws {
        try writeSpectrums(features)
        try writeSpectralFluxes(features)
        try writePeakHeights(features)
        try writePeakFluxes(features)
        try writePeakLocations(features)
    }

    func writeSpectrums(features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresSpectrum.rawValue) else {
            throw Error.DatasetNotFound
        }

        let featureSize = Configuration.bandNotes.count
        let data = features.flatMap({ $0.spectrum })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    func writeSpectralFluxes(features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresFlux.rawValue) else {
            throw Error.DatasetNotFound
        }

        let featureSize = Configuration.bandNotes.count
        let data = features.flatMap({ $0.spectralFlux })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    func writePeakHeights(features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresPeakHeights.rawValue) else {
            throw Error.DatasetNotFound
        }

        let featureSize = Configuration.bandNotes.count
        let data = features.flatMap({ $0.peakHeights })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    func writePeakFluxes(features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresPeakFlux.rawValue) else {
            throw Error.DatasetNotFound
        }

        let featureSize = Configuration.bandNotes.count
        let data = features.flatMap({ $0.peakFlux })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    func writePeakLocations(features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresPeakLocations.rawValue) else {
            throw Error.DatasetNotFound
        }

        let featureSize = Configuration.bandNotes.count
        let data = features.flatMap({ $0.peakLocations })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    public func readFeatureAtIndex(index: Int) throws -> Feature {
        var feature = Feature()
        feature.spectrum = ValueArray(try readSpectrumAtIndex(index))
        feature.spectralFlux = ValueArray(try readFluxAtIndex(index))
        feature.peakHeights = ValueArray(try readPeakHeightsAtIndex(index))
        feature.peakFlux = ValueArray(try readPeakFluxAtIndex(index))
        feature.peakLocations = ValueArray(try readPeakLocationsAtIndex(index))
        return feature
    }

    func readSpectrumAtIndex(index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresSpectrum.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index, 0..])
    }

    func readFluxAtIndex(index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresFlux.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index, 0..])
    }

    func readPeakHeightsAtIndex(index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresPeakHeights.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index, 0..])
    }

    func readPeakFluxAtIndex(index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresPeakFlux.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index, 0..])
    }

    func readPeakLocationsAtIndex(index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresPeakLocations.rawValue) else {
            throw Error.DatasetNotFound
        }
        return try dataset.read([index, 0..])
    }
}
