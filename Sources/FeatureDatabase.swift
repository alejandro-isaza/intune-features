// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import HDF5Kit
import Upsurge



open class FeatureDatabase {
    public enum Error: Swift.Error {
        case datasetNotFound
        case datasetNotCompatible
    }
    

    open let chunkSize: Int
    let filePath: String
    let file: File

    public init(filePath: String, chunkSize: Int = 1024, configuration: Configuration) {
        self.filePath = filePath
        self.chunkSize = chunkSize

        file = File.create(filePath, mode: .truncate)!
        file.createGroup("events")
        file.createGroup("labels")
        file.createGroup("features")
        
        for table in Table.allValues {
            table.createInFile(file, chunkSize: chunkSize, configuration: configuration)
        }
    }

    open func flush() {
        file.flush()
    }
}


// MARK: Events

public extension FeatureDatabase {
    public func writeEvents(_ events: [Event]) throws {
        try writeEventStarts(events)
        try writeEventDurations(events)
        try writeEventNotes(events)
        try writeEventVelocities(events)
    }

    func writeEventStarts(_ events: [Event]) throws {
        guard let dataset = file.openIntDataset(Table.eventsStart.rawValue) else {
            throw Error.datasetNotFound
        }
        let data = events.map({ $0.start })
        try dataset.append(data, dimensions: [events.count])
    }

    func writeEventDurations(_ events: [Event]) throws {
        guard let dataset = file.openIntDataset(Table.eventsDuration.rawValue) else {
            throw Error.datasetNotFound
        }
        let data = events.map({ $0.duration })
        try dataset.append(data, dimensions: [events.count])
    }

    func writeEventNotes(_ events: [Event]) throws {
        guard let dataset = file.openIntDataset(Table.eventsNote.rawValue) else {
            throw Error.datasetNotFound
        }
        let data = events.map({ $0.note.midiNoteNumber })
        try dataset.append(data, dimensions: [events.count])
    }

    func writeEventVelocities(_ events: [Event]) throws {
        guard let dataset = file.openFloatDataset(Table.eventsVelocity.rawValue) else {
            throw Error.datasetNotFound
        }
        let data = events.map({ $0.velocity })
        try dataset.append(data, dimensions: [events.count])
    }

    public func readEventAtIndex(_ index: Int) throws -> Event {
        var event = Event()
        event.start = try readEventStartAtIndex(index)
        event.duration = try readEventDurationAtIndex(index)
        event.note = try readEventNoteAtIndex(index)
        event.velocity = try readEventVelocityAtIndex(index)
        return event
    }

    func readEventStartAtIndex(_ index: Int) throws -> Int {
        guard let dataset = file.openIntDataset(Table.eventsStart.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index]).first!
    }

    func readEventDurationAtIndex(_ index: Int) throws -> Int {
        guard let dataset = file.openIntDataset(Table.eventsDuration.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index]).first!
    }

    func readEventNoteAtIndex(_ index: Int) throws -> Note {
        guard let dataset = file.openIntDataset(Table.eventsNote.rawValue) else {
            throw Error.datasetNotFound
        }
        return Note(midiNoteNumber: try dataset.read([index]).first!)
    }

    func readEventVelocityAtIndex(_ index: Int) throws -> Float {
        guard let dataset = file.openFloatDataset(Table.eventsVelocity.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index]).first!
    }
}


// MARK: Labels

public extension FeatureDatabase {
    public func writeLabels(_ labels: [Label]) throws {
        try writeLabelOnsets(labels)
        try writeLabelPolyphonies(labels)
        try writeLabelNotes(labels)
    }

    func writeLabelOnsets(_ labels: [Label]) throws {
        guard let dataset = file.openFloatDataset(Table.labelsOnset.rawValue) else {
            throw Error.datasetNotFound
        }
        let onsets = labels.map({ $0.onset })
        try dataset.append(onsets, dimensions: [onsets.count])
    }

    func writeLabelPolyphonies(_ labels: [Label]) throws {
        guard let dataset = file.openFloatDataset(Table.labelsPolyphony.rawValue) else {
            throw Error.datasetNotFound
        }
        let polyphonies = labels.map({ $0.polyphony })
        try dataset.append(polyphonies, dimensions: [polyphonies.count])
    }

    func writeLabelNotes(_ labels: [Label]) throws {
        guard let dataset = file.openFloatDataset(Table.labelsNotes.rawValue) else {
            throw Error.datasetNotFound
        }
        guard let noteCount = labels.first?.notes.count else {
            return
        }
        let notes = labels.flatMap({ $0.notes })
        try dataset.append(notes, dimensions: [labels.count, noteCount])
    }

    public func readLabelAtIndex(_ index: Int) throws -> Label {
        var label = Label(noteCount: 0)
        label.onset = try readLabelOnsetAtIndex(index)
        label.polyphony = try readLabelPolyphonyAtIndex(index)
        label.notes = try readLabelNotesAtIndex(index)
        return label
    }

    func readLabelOnsetAtIndex(_ index: Int) throws -> Float {
        guard let dataset = file.openFloatDataset(Table.labelsOnset.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index]).first!
    }

    func readLabelPolyphonyAtIndex(_ index: Int) throws -> Float {
        guard let dataset = file.openFloatDataset(Table.labelsPolyphony.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index]).first!
    }

    func readLabelNotesAtIndex(_ index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.labelsNotes.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index, 0..])
    }
}


// MARK: Feature Writing

public extension FeatureDatabase {
    func writeFeatures(_ features: [Feature]) throws {
        try writeSpectrums(features)
        try writeSpectralFluxes(features)
        try writePeakHeights(features)
        try writePeakFluxes(features)
        try writePeakLocations(features)
    }

    func writeSpectrums(_ features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresSpectrum.rawValue) else {
            throw Error.datasetNotFound
        }

        guard let featureSize = features.first?.spectrum.count else {
            return
        }
        let data = features.flatMap({ $0.spectrum })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    func writeSpectralFluxes(_ features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresFlux.rawValue) else {
            throw Error.datasetNotFound
        }

        guard let featureSize = features.first?.spectrum.count else {
            return
        }
        let data = features.flatMap({ $0.spectralFlux })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    func writePeakHeights(_ features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresPeakHeights.rawValue) else {
            throw Error.datasetNotFound
        }

        guard let featureSize = features.first?.spectrum.count else {
            return
        }
        let data = features.flatMap({ $0.peakHeights })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    func writePeakFluxes(_ features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresPeakFlux.rawValue) else {
            throw Error.datasetNotFound
        }

        guard let featureSize = features.first?.spectrum.count else {
            return
        }
        let data = features.flatMap({ $0.peakFlux })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    func writePeakLocations(_ features: [Feature]) throws {
        guard let dataset = file.openFloatDataset(Table.featuresPeakLocations.rawValue) else {
            throw Error.datasetNotFound
        }

        guard let featureSize = features.first?.spectrum.count else {
            return
        }
        let data = features.flatMap({ $0.peakLocations })
        try dataset.append(data, dimensions: [features.count, featureSize])
    }

    public func readFeatureAtIndex(_ index: Int) throws -> Feature {
        var feature = Feature(bandCount: 0)
        feature.spectrum = ValueArray(try readSpectrumAtIndex(index))
        feature.spectralFlux = ValueArray(try readFluxAtIndex(index))
        feature.peakHeights = ValueArray(try readPeakHeightsAtIndex(index))
        feature.peakFlux = ValueArray(try readPeakFluxAtIndex(index))
        feature.peakLocations = ValueArray(try readPeakLocationsAtIndex(index))
        return feature
    }

    func readSpectrumAtIndex(_ index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresSpectrum.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index, 0..])
    }

    func readFluxAtIndex(_ index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresFlux.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index, 0..])
    }

    func readPeakHeightsAtIndex(_ index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresPeakHeights.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index, 0..])
    }

    func readPeakFluxAtIndex(_ index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresPeakFlux.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index, 0..])
    }

    func readPeakLocationsAtIndex(_ index: Int) throws -> [Float] {
        guard let dataset = file.openFloatDataset(Table.featuresPeakLocations.rawValue) else {
            throw Error.datasetNotFound
        }
        return try dataset.read([index, 0..])
    }
}
