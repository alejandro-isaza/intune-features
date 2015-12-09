//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import HDF5Kit

/// Labels a window of audio data by the notes being played
public struct Label: Hashable, Equatable {
    /// The range of notes that can be represented with a label (this needs to be a multiple of 12)
    public static let representableRange = 36...95

    /// The length of time in seconds for which a new note is considered an onset
    public static let onsetTime = 0.05

    /// The sparse array representing the on notes
    public var notesArray = [Double](count: Label.representableRange.count, repeatedValue: 0)

    /// The sparse array representing the onset notes
    public var onsetsArray = [Double](count: Label.representableRange.count, repeatedValue: 0)
    
    public var hashValue: Int {
        // DJB Hash Function
        var hash = 5381
        for val in notesArray {
            hash = ((hash << 5) &+ hash) &+ Int(val)
        }
        return hash
    }

    public init() {
    }

    public init(notes: [Double], onsets: [Double]) {
        self.notesArray = notes
        self.onsetsArray = onsets
    }

    public init(note: Note, atTime time: Double) {
        addNote(note, atTime: time)
    }

    mutating public func addNote(note: Note, atTime time: Double) {
        guard let index = indexForNote(note)  else {
            return
        }

        notesArray[index] = 1
        if abs(time) < Label.onsetTime {
            onsetsArray[index] = (-abs(time) + Label.onsetTime) / Label.onsetTime
        }
    }

    /// The list of notes in this label
    public var notes: [Note] {
        var notes = [Note]()
        for i in 0..<notesArray.count {
            if notesArray[i] > 0.5 {
                notes.append(noteAtIndex(i))
            }
        }
        return notes
    }

    func indexForNote(note: Note) -> Int? {
        let index = note.midiNoteNumber - Label.representableRange.startIndex
        guard index >= 0 && index < Label.representableRange.count else {
            return nil
        }
        return index
    }

    func noteAtIndex(index: Int) -> Note {
        let midiNoteNumber = index + Label.representableRange.startIndex
        return Note(midiNoteNumber: midiNoteNumber)
    }
}

public func ==(lhs: Label, rhs: Label) -> Bool {
    return lhs.notesArray == rhs.notesArray && lhs.onsetsArray == rhs.onsetsArray
}


// MARK: HDF5

extension Label {
    static func readFromFile(file: File, start: Int, count: Int) -> [Label] {
        let noteLabelDataset = file.openDataset(FeatureDatabase.onLabelDatasetName, type: Double.self)!
        let onsetLabelDataset = file.openDataset(FeatureDatabase.onsetLabelDatasetName, type: Double.self)!

        let fileSpace = Dataspace(noteLabelDataset.space)
        let featureSize = fileSpace.dims[1]
        assert(featureSize == Label.representableRange.count)
        fileSpace.select(start: [start, 0], stride: nil, count: [count, featureSize], block: nil)

        let memSpace = Dataspace(dims: [count, featureSize])

        var noteLabels = [Double](count: count * featureSize, repeatedValue: 0.0)
        noteLabelDataset.readDouble(&noteLabels, memSpace: memSpace, fileSpace: fileSpace)

        var onsetLabels = [Double](count: count * featureSize, repeatedValue: 0.0)
        onsetLabelDataset.readDouble(&onsetLabels, memSpace: memSpace, fileSpace: fileSpace)

        var labels = [Label]()
        labels.reserveCapacity(count)
        for i in 0..<count {
            let start = i * featureSize
            let end = (i + 1) * featureSize
            let notes = noteLabels[start..<end]
            let onsets = onsetLabels[start..<end]
            let label = Label(notes: [Double](notes), onsets: [Double](onsets))
            labels.append(label)
        }
        return labels
    }

    static func write<C: CollectionType where C.Generator.Element == Label, C.Index == Int>(labels: C, toFile file: File) {
        writeNotes(labels, toFile: file)
        writeOnsets(labels, toFile: file)
    }

    static func writeNotes<C: CollectionType where C.Generator.Element == Label, C.Index == Int>(labels: C, toFile file: HDF5Kit.File) {
        guard let dataset = file.openDataset(FeatureDatabase.onLabelDatasetName, type: Int.self) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.onLabelDatasetName) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += labels.count

        let filespace = dataset.space
        filespace.select(start: [currentSize, 0], stride: nil, count: [labels.count, Label.representableRange.count], block: nil)

        let memspace = Dataspace(dims: [labels.count, Label.representableRange.count])

        var data = [Double]()
        data.reserveCapacity(labels.count * Label.representableRange.count)
        for label in labels {
            data.appendContentsOf(label.notesArray)
        }

        if !dataset.writeDouble(data, memSpace: memspace, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }

    static func writeOnsets<C: CollectionType where C.Generator.Element == Label, C.Index == Int>(labels: C, toFile file: HDF5Kit.File) {
        guard let dataset = file.openDataset(FeatureDatabase.onsetLabelDatasetName, type: Int.self) else {
            preconditionFailure("Existing file doesn't have a \(FeatureDatabase.onsetLabelDatasetName) dataset")
        }

        let currentSize = dataset.extent[0]
        dataset.extent[0] += labels.count

        let filespace = dataset.space
        filespace.select(start: [currentSize, 0], stride: nil, count: [labels.count, Label.representableRange.count], block: nil)

        let memspace = Dataspace(dims: [labels.count, Label.representableRange.count])

        var data = [Double]()
        data.reserveCapacity(labels.count * Label.representableRange.count)
        for label in labels {
            data.appendContentsOf(label.onsetsArray)
        }

        if !dataset.writeDouble(data, memSpace: memspace, fileSpace: filespace) {
            fatalError("Failed to write features to database")
        }
    }
}
