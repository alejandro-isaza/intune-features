//  Copyright © 2016 Venture Media. All rights reserved.

import FeatureExtraction

class NetworkDecoder {
    let configuration: Configuration
    var lastOnsetValue = Float()
    var peakCandidate: Float?
    var valleyCandidate: Float?
    var postponeOnset: Int?

    var currentNotes = [Note]()
    var eventAction: ([Note] -> Void)?

    init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    func processOutput<C: CollectionType where C.Generator.Element == Float>(onsetValue: Float, polyphonyValue: Float, noteValues: C) {
        if let postponeOnset = postponeOnset {
            if postponeOnset == 0 {
                processOnset(onsetValue, polyphonyValue: polyphonyValue, noteValues: noteValues)
                self.postponeOnset = nil
            } else {
                self.postponeOnset = postponeOnset - 1
            }
        }

        if let peak = peakCandidate {
            if peak > onsetValue {
                postponeOnset = 3
                peakCandidate = nil
            } else if peak < onsetValue {
                peakCandidate = onsetValue
            }
        } else {
            if lastOnsetValue < onsetValue && onsetValue > 0.5 {
                peakCandidate = onsetValue
            }
        }
        lastOnsetValue = onsetValue
    }

    func processOnset<C: CollectionType where C.Generator.Element == Float>(onsetValue: Float, polyphonyValue: Float, noteValues: C) {
        let polyphony = Int(polyphonyValue)
        var topNotes = [(Float, Note)](count: polyphony, repeatedValue: (0, Note(midiNoteNumber: 0)))
        for (i, value) in noteValues.enumerate() {
            let note = Note(midiNoteNumber: i + configuration.representableNoteRange.startIndex)
            sortedInsertNote(note, value: value, into: &topNotes)
        }

        var newNotes = [Note]()
        for (value, note) in topNotes {
            if value == 0 {
                break
            }

            newNotes.append(note)
        }

        eventAction?(newNotes)
        currentNotes = newNotes
    }

    private func sortedInsertNote(note: Note, value: Float, inout into array: [(Float, Note)]) {
        for i in 0..<array.count {
            if value > array[i].0 {
                array.insert((value, note), atIndex: i)
                array.removeLast()
                return
            }
        }
    }

    func reset() {
        currentNotes.removeAll()
    }
}
