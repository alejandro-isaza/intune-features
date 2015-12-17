//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import HDF5Kit

/// Labels a window of audio data by the notes being played
public struct Label: Hashable, Equatable, CustomStringConvertible {
    /// The range of notes that can be represented with a label (this needs to be a multiple of 12)
    public static let representableRange = 36...95

    /// The number of notes that can be represented with a label
    public static let noteCount = Label.representableRange.count

    /// The length of time in seconds for which a new note is considered an onset
    public static let onsetTime = 0.05

    /// Whether to include a 'noise' label
    public static let noiseLabel = false

    /// The sparse array representing the on notes
    public var notesArray = [Double](count: Label.noteCount, repeatedValue: 0)

    /// The sparse array representing the onset notes
    public var onsetsArray = [Double](count: Label.noteCount, repeatedValue: 0)

    /// A value for representing "no note"
    public var noiseValue = 1.0

    public init() {
    }

    public init(notes: [Double], onsets: [Double]) {
        assert(notes.count ==  Label.representableRange.count)
        assert(onsets.count ==  Label.representableRange.count)
        self.notesArray = notes
        self.onsetsArray = onsets

        if notesArray.reduce(0.0, combine: +) + onsetsArray.reduce(0.0, combine: +) == 0 {
            noiseValue = 1.0
        } else {
            noiseValue = 0.0
        }
    }

    public init(note: Note, atTime time: Double) {
        addNote(note, atTime: time)
    }

    mutating public func addNote(note: Note, atTime time: Double) {
        guard let index = indexForNote(note)  else {
            return
        }

        noiseValue = 0.0

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

    /// The list of note onsets in this label
    public var onsets: [Note] {
        var onsets = [Note]()
        for i in 0..<onsetsArray.count {
            if onsetsArray[i] > 0.5 {
                onsets.append(noteAtIndex(i))
            }
        }
        return onsets
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

    public var hashValue: Int {
        // DJB Hash Function
        var hash = 5381
        for val in notesArray {
            hash = ((hash << 5) &+ hash) &+ Int(val * 1000)
        }
        for val in onsetsArray {
            hash = ((hash << 5) &+ hash) &+ Int(val * 1000)
        }
        hash = ((hash << 5) &+ hash) &+ Int(noiseValue * 1000)
        return hash
    }

    public var description: String {
        if noiseValue > 0.5 {
            return "Noise"
        }

        var string = "["
        let notes = self.notes
        let onsets = Set<Note>(self.onsets)
        for note in notes {
            string += note.description
            if onsets.contains(note) {
                string += "*"
            }
            string += ", "
        }
        if string.hasSuffix(", ") {
            string.removeRange(string.endIndex.advancedBy(-2)..<string.endIndex)
        }
        string += "]"
        return string
    }
}

public func ==(lhs: Label, rhs: Label) -> Bool {
    return lhs.notesArray == rhs.notesArray && lhs.onsetsArray == rhs.onsetsArray
}


// MARK: HDF5

extension Label {
    static func readFromFile(file: File, start: Int, count: Int) -> [Label] {
        let onTable = Table(file: file, name: FeatureDatabase.onLabelDatasetName, rowSize: Label.noteCount)
        let onsetTable = Table(file: file, name: FeatureDatabase.onsetLabelDatasetName, rowSize: Label.noteCount)
        
        var onLabels = [Double](count: count * Label.noteCount, repeatedValue: 0.0)
        let onCount = try! onTable.readFromRow(start, count: count, into: &onLabels)

        var onsetLabels = [Double](count: count * Label.noteCount, repeatedValue: 0.0)
        let onsetCount = try! onsetTable.readFromRow(start, count: count, into: &onsetLabels)

        assert(onCount == onsetCount)

        var labels = [Label]()
        labels.reserveCapacity(onCount)
        for i in 0..<onCount {
            let start = i * Label.noteCount
            let end = (i + 1) * Label.noteCount
            let notes = onLabels[start..<end]
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
        let table = Table(file: file, name: FeatureDatabase.onLabelDatasetName, rowSize: Label.noteCount)

        var data = [Double]()
        data.reserveCapacity(labels.count * Label.noteCount)
        for label in labels {
            data.appendContentsOf(label.notesArray)
        }

        try! table.appendData(data)
    }

    static func writeOnsets<C: CollectionType where C.Generator.Element == Label, C.Index == Int>(labels: C, toFile file: HDF5Kit.File) {
        let table = Table(file: file, name: FeatureDatabase.onsetLabelDatasetName, rowSize: Label.noteCount)

        var data = [Double]()
        data.reserveCapacity(labels.count * Label.noteCount)
        for label in labels {
            data.appendContentsOf(label.onsetsArray)
        }

        try! table.appendData(data)
    }
}
