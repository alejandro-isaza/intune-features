//  Copyright © 2016 Venture Media. All rights reserved.

import FeatureExtraction
import HDF5Kit

class DecayModel {
    let file: File
    let dataset: FloatDataset

    init() {
        guard let file = File.open("note_curves.h5", mode: .ReadOnly) else {
            fatalError("Note curve parameters file 'note_curves.h5' not found.")
        }
        self.file = file
        dataset = file.openFloatDataset("curve_coefficients")!
    }

    func decayValueForNote(note: Note, atOffset offset: Int) -> Float {
        if offset < 0 || offset > 44100 {
            return 0
        }

        let noteParameters = dataset[note.midiNoteNumber - Note.representableRange.startIndex, 0..]
        let a = noteParameters[0]
        let b = Float(offset) - noteParameters[1]
        let c = noteParameters[2]
        let d = noteParameters[3]
        return a * exp(b * b * c) + d
    }
}
