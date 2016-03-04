//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

public struct Note : Equatable, Hashable, CustomStringConvertible {
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
