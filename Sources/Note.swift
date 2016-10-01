// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation

public struct Note : Equatable, Hashable, CustomStringConvertible {
    public enum NoteType: Int {
        case c  = 0
        case cSharp = 1
        case d  = 2
        case dSharp = 3
        case e  = 4
        case f  = 5
        case fSharp = 6
        case g  = 7
        case gSharp = 8
        case a  = 9
        case aSharp = 10
        case b  = 11

        public static let count = 12
    }

    public var note: NoteType
    public var octave: Int

    public var isSharp: Bool {
        return note == .cSharp || note == .dSharp || note == .fSharp || note == .gSharp || note == .aSharp
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
        case .c: return "C\(octave)"
        case .d: return "D\(octave)"
        case .e: return "E\(octave)"
        case .f: return "F\(octave)"
        case .g: return "G\(octave)"
        case .a: return "A\(octave)"
        case .b: return "B\(octave)"
        case .cSharp: return "C♯\(octave)"
        case .dSharp: return "D♯\(octave)"
        case .fSharp: return "F♯\(octave)"
        case .gSharp: return "G♯\(octave)"
        case .aSharp: return "A♯\(octave)"
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
