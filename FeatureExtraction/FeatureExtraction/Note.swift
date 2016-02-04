//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

public struct Note : Equatable, Hashable, CustomStringConvertible {
    /// The range of notes that can be represented with a label (this needs to be a multiple of 12)
    public static let representableRange = 36...95

    /// The number of notes that can be represented with a label
    public static let noteCount = representableRange.count

    public enum NoteType: Int {
        case C  = 0
        case CSharp = 1
        case D  = 2
        case DSharp = 3
        case E  = 4
        case F  = 5
        case FSharp = 6
        case G  = 7
        case GSharp = 8
        case A  = 9
        case ASharp = 10
        case B  = 11

        static let count = 12
    }

    public var note: NoteType
    public var octave: Int

    public var isSharp: Bool {
        return note == .CSharp || note == .DSharp || note == .FSharp || note == .GSharp || note == .ASharp
    }

    public var midiNoteNumber: Int {
        return 12 * (octave + 1) + note.rawValue
    }

    public init(midiNoteNumber: Int) {
        octave = midiNoteNumber / 12 - 1
        note = NoteType(rawValue: midiNoteNumber % 12)!
    }

    public init(note: NoteType, octave: Int) {
        self.note = note
        self.octave = octave
    }

    public var description : String {
        switch note {
        case .C: return "C\(octave)"
        case .D: return "D\(octave)"
        case .E: return "E\(octave)"
        case .F: return "F\(octave)"
        case .G: return "G\(octave)"
        case .A: return "A\(octave)"
        case .B: return "B\(octave)"
        case .CSharp: return "C♯\(octave)"
        case .DSharp: return "D♯\(octave)"
        case .FSharp: return "F♯\(octave)"
        case .GSharp: return "G♯\(octave)"
        case .ASharp: return "A♯\(octave)"
        }
    }

    public var hashValue: Int {
        return midiNoteNumber.hashValue
    }

    public var frequency: Double {
        return noteToFreq(Double(midiNoteNumber))
    }
}

public func ==(lhs: Note, rhs: Note) -> Bool {
    return lhs.note == rhs.note && lhs.octave == rhs.octave
}

public func vectorFromNotes(notes: [Note]) -> [Float] {
    var vector = [Float](count: Note.representableRange.count, repeatedValue: 0.0)
    for note in notes {
        let index = note.midiNoteNumber - Note.representableRange.startIndex
        vector[index] = 1.0
    }
    return vector
}

public func notesFromVector<C: CollectionType where C.Generator.Element == Float, C.Index == Int>(vector: C) -> [Note] {
    precondition(vector.count == Note.representableRange.count)
    var notes = [Note]()
    for (index, value) in vector.enumerate() {
        if value < 0.5 {
            continue
        }
        let note = Note(midiNoteNumber: index + Note.representableRange.startIndex)
        notes.append(note)
    }
    return notes
}
