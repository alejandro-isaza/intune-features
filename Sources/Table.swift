// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import HDF5Kit

public enum Table: String {
    case eventsStart = "/events/start"
    case eventsDuration = "/events/duration"
    case eventsNote = "/events/note"
    case eventsVelocity = "/events/velocity"

    case labelsOnset = "/labels/onset"
    case labelsPolyphony = "/labels/polyphony"
    case labelsNotes = "/labels/notes"

    case featuresSpectrum = "/features/spectrum"
    case featuresFlux = "/features/flux"
    case featuresPeakLocations = "/features/peak_locations"
    case featuresPeakHeights = "/features/peak_heights"
    case featuresPeakFlux = "/features/peak_flux"

    public static let allValues = [
        eventsStart,
        eventsDuration,
        eventsNote,
        eventsVelocity,
        labelsOnset,
        labelsPolyphony,
        labelsNotes,
        featuresSpectrum,
        featuresFlux,
        featuresPeakLocations,
        featuresPeakHeights,
        featuresPeakFlux
    ]

    public static let features = [
        featuresSpectrum,
        featuresFlux,
        featuresPeakHeights,
        featuresPeakLocations,
        featuresPeakFlux
    ]

    public var rank: Int {
        switch self {
        case eventsStart: return 1
        case eventsDuration: return 1
        case eventsNote: return 1
        case eventsVelocity: return 1

        case labelsOnset: return 1
        case labelsPolyphony: return 1
        case labelsNotes: return 2

        case featuresSpectrum: return 2
        case featuresFlux: return 2
        case featuresPeakLocations: return 2
        case featuresPeakHeights: return 2
        case featuresPeakFlux: return 2
        }
    }

    public func maxDims(configuration: Configuration) -> [Int] {
        let featureSize = configuration.bandCount

        switch self {
        case eventsStart: return [-1]
        case eventsDuration: return [-1]
        case eventsNote: return [-1]
        case eventsVelocity: return [-1]

        case labelsOnset: return [-1]
        case labelsPolyphony: return [-1]
        case labelsNotes: return [-1, configuration.representableNoteRange.count]

        case featuresSpectrum: fallthrough
        case featuresFlux: fallthrough
        case featuresPeakLocations: fallthrough
        case featuresPeakHeights: fallthrough
        case featuresPeakFlux:
            return [-1, featureSize]
        }
    }

    public func chunkDimensions(chunkSize: Int, configuration: Configuration) -> [Int] {
        let featureSize = configuration.bandCount

        switch self {
        case eventsStart: return [chunkSize]
        case eventsDuration: return [chunkSize]
        case eventsNote: return [chunkSize]
        case eventsVelocity: return [chunkSize]

        case labelsOnset: return [chunkSize]
        case labelsPolyphony: return [chunkSize]
        case labelsNotes: return [chunkSize, configuration.representableNoteRange.count]

        case featuresSpectrum: fallthrough
        case featuresFlux: fallthrough
        case featuresPeakLocations: fallthrough
        case featuresPeakHeights: fallthrough
        case featuresPeakFlux:
            return [chunkSize, featureSize]
        }
    }

    public func createInFile(file: File, chunkSize: Int, configuration: Configuration) {
        let dims = [Int](count: rank, repeatedValue: 0)
        let dataspace = Dataspace(dims: dims, maxDims: maxDims(configuration))
        switch self {
        case eventsStart: fallthrough
        case eventsDuration: fallthrough
        case eventsNote:
            file.createIntDataset(rawValue, dataspace: dataspace, chunkDimensions: chunkDimensions(chunkSize, configuration: configuration))

        case eventsVelocity: fallthrough
        case labelsOnset: fallthrough
        case labelsPolyphony: fallthrough
        case labelsNotes: fallthrough
        case featuresSpectrum: fallthrough
        case featuresFlux: fallthrough
        case featuresPeakLocations: fallthrough
        case featuresPeakHeights: fallthrough
        case featuresPeakFlux:
            file.createFloatDataset(rawValue, dataspace: dataspace, chunkDimensions: chunkDimensions(chunkSize, configuration: configuration))
        }
    }
}
