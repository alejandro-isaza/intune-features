//  Copyright © 2016 Venture Media. All rights reserved.

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
        featuresPeakHeights
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
        }
    }

    public var maxDims: [Int] {
        let featureSize = FeatureBuilder.bandNotes.count

        switch self {
        case eventsStart: return [-1]
        case eventsDuration: return [-1]
        case eventsNote: return [-1]
        case eventsVelocity: return [-1]

        case labelsOnset: return [-1]
        case labelsPolyphony: return [-1]
        case labelsNotes: return [-1, Note.noteCount]

        case featuresSpectrum: return [-1, featureSize]
        case featuresFlux: return [-1, featureSize]
        case featuresPeakLocations: return [-1, featureSize]
        case featuresPeakHeights: return [-1, featureSize]
        }
    }

    public var chunkDimensions: [Int] {
        let chunkSize = 1024
        let featureSize = FeatureBuilder.bandNotes.count

        switch self {
        case eventsStart: return [chunkSize]
        case eventsDuration: return [chunkSize]
        case eventsNote: return [chunkSize]
        case eventsVelocity: return [chunkSize]

        case labelsOnset: return [chunkSize]
        case labelsPolyphony: return [chunkSize]
        case labelsNotes: return [chunkSize, Note.noteCount]

        case featuresSpectrum: return [chunkSize, featureSize]
        case featuresFlux: return [chunkSize, featureSize]
        case featuresPeakLocations: return [chunkSize, featureSize]
        case featuresPeakHeights: return [chunkSize, featureSize]
        }
    }

    public func createInFile(file: File) {
        let dims = [Int](count: rank, repeatedValue: 0)
        let dataspace = Dataspace(dims: dims, maxDims: maxDims)
        switch self {
        case eventsStart: fallthrough
        case eventsDuration: fallthrough
        case eventsNote:
            file.createIntDataset(rawValue, dataspace: dataspace, chunkDimensions: chunkDimensions)

        case eventsVelocity: fallthrough
        case labelsOnset: fallthrough
        case labelsPolyphony: fallthrough
        case labelsNotes: fallthrough
        case featuresSpectrum: fallthrough
        case featuresFlux: fallthrough
        case featuresPeakLocations: fallthrough
        case featuresPeakHeights:
            file.createFloatDataset(rawValue, dataspace: dataspace, chunkDimensions: chunkDimensions)
        }
    }
}
