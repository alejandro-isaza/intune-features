//  Copyright © 2016 Venture Media. All rights reserved.

import FeatureExtraction
import HDF5Kit

class DecayModel {
    let representableNoteRange: Range<Int>
    let parameterCount = 4
    let file: File

    let parameters: [Float]
    let sums: [Float]

    init(representableNoteRange: Range<Int>) {
        self.representableNoteRange = representableNoteRange
        guard let file = File.open("note_curves.h5", mode: .ReadOnly) else {
            fatalError("Note curve parameters file 'note_curves.h5' not found.")
        }
        self.file = file

        let paramsDataset = file.openFloatDataset("curve_coefficients")!
        parameters = try! paramsDataset.read()

        let sumsDataset = file.openFloatDataset("curve_sum")!
        sums = try! sumsDataset.read()

        precondition(parameters.count == parameterCount * representableNoteRange.count)
        precondition(sums.count == representableNoteRange.count * 4)
    }

    func decayValueForNote(note: Note, atOffset offset: Int) -> Float {
        if offset < 0 || offset > 44100 {
            return 0
        }

        let noteIndex = note.midiNoteNumber - representableNoteRange.startIndex
        let index = noteIndex * parameterCount
        let a = parameters[index + 0]
        let b = Float(offset) - parameters[index + 1]
        let c = parameters[index + 2]
        let d = parameters[index + 3]
        return a * exp(b * b * c) + d
    }

    func normalizationForNote(note: Note, windowSize: Int) -> Float {
        let index = note.midiNoteNumber - representableNoteRange.startIndex
        switch windowSize {
        case 8192: return sums[index + 3 * representableNoteRange.count]
        case 4096: return sums[index + 2 * representableNoteRange.count]
        case 2048: return sums[index + 1 * representableNoteRange.count]
        case 1024: return sums[index + 0 * representableNoteRange.count]
        default: fatalError("Invalid window size")
        }
    }
}
