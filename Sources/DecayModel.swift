//  Copyright © 2016 Venture Media. All rights reserved.

import HDF5Kit

public class DecayModel {
    let representableNoteRange: Range<Int>
    let parameterCount = 4
    let file: File

    let parameters: [Float]
    let sums: [Float]

    public init(representableNoteRange: Range<Int>) {
        self.representableNoteRange = representableNoteRange

        let curvesPath: String
        let bundle = NSBundle(forClass: self.dynamicType)
        if let path = bundle.pathForResource("note_curves", ofType: "h5") {
            curvesPath = path
        } else if let subBundlePath = bundle.pathForResource("NoteCurves", ofType: "bundle"),
            subBundle = NSBundle(path: subBundlePath),
            path = subBundle.pathForResource("note_curves", ofType: "h5") {
            curvesPath = path
        } else {
            fatalError("Note curves file not found")
        }
        
        guard let file = File.open(curvesPath, mode: .ReadOnly) else {
            fatalError("Note curve parameters file not found.")
        }
        self.file = file

        let paramsDataset = file.openFloatDataset("curve_coefficients")!
        parameters = try! paramsDataset.read()

        let sumsDataset = file.openFloatDataset("curve_sum")!
        sums = try! sumsDataset.read()

        precondition(parameters.count == parameterCount * representableNoteRange.count)
        precondition(sums.count == representableNoteRange.count * 4)
    }

    public func decayValueForNote(note: Note, atOffset offset: Int) -> Float {
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

    public func normalizationForNote(note: Note, windowSize: Int) -> Float {
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
