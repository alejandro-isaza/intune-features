//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

public func noteToFreq(n: Double) -> Double {
    return 440 * exp2((n - 69.0) / 12.0)
}

public func freqToNote(f: Double) -> Double {
    return (12 * log2(f / 440.0)) + 69.0
}

public enum Note: Int {
    case C  = 0
    case Cs = 1
    case D  = 2
    case Ds = 3
    case E  = 4
    case F  = 5
    case Fs = 6
    case G  = 7
    case Gs = 8
    case A  = 9
    case As = 10
    case B  = 11
}

/// Go from a MIDI note number to an octave number and a note
public func noteComponents(n: Int) -> (Int, Note) {
    let octave = n / 12 - 1
    let note = Note(rawValue: n % 12)!
    return (octave, note)
}
