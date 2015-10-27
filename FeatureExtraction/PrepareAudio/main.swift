import Foundation
import AudioToolbox
import FeatureExtraction
import Peak

let rootPath = "~/Box Sync/Intune Music/Training/Audio/"
let folders: [(String, String, Range<Int>)] = [
    ("AcousticGrandPiano_YDP/", ".caf", 24...107),
    ("Arachno/", ".caf", 24...107),
    ("FFNotes/", ".aiff", 21...108),
    ("FluidR3_GM2-2/", ".caf", 24...107),
    ("GeneralUser_GS_MuseScore_v1.442/", ".caf", 24...107),
    ("MFNotes/", ".aiff", 23...96),
    ("MIDI/", ".aiff", 24...107),
    ("Piano_Rhodes_73/", ".caf", 36...107),
    ("Piano_Yamaha_DX7/", ".caf", 24...107),
    ("TimGM6mb/", ".caf", 24...107),
    ("VenturePiano1/", ".aiff", 21...99),
    ("VenturePiano2/", ".wav", 24...96),
    ("VenturePiano3/", ".wav", 24...96),
    ("VenturePiano4/", ".wav", 24...96),
    ("VenturePianoQuiet1/", ".m4a", 24...96),
    ("VenturePianoQuiet2/", ".m4a", 24...96),
    ("VenturePianoQuiet3/", ".m4a", 24...96),
    ("VenturePianoQuiet4/", ".m4a", 24...96)
]

let windowSize = 40000
let outputExt = ".m4a"

var audioData = [Double](count: windowSize, repeatedValue: 0.0)

for (folder, ext, notes) in folders {
    for note in notes {
        let inFilePath = ("\( rootPath)\(folder)\(note)\(ext)" as NSString).stringByExpandingTildeInPath
        let outFilePath = ("\( rootPath)\(folder)trimmed/\(note)\(outputExt)" as NSString).stringByExpandingTildeInPath
        guard let inAudioFile = AudioFile.open(inFilePath) else { continue }
        let outAudioFile = AudioFile.createLossless(outFilePath, sampleRate: 44100, overwrite: true)
        var silenceData = [0.0]
        while silenceData[0] < 0.01 {
            inAudioFile.readFrames(&silenceData, count: 1)
        }

        while let count = inAudioFile.readFrames(&audioData, count: windowSize) {
            if count == 0 {
                break
            } else {
                outAudioFile?.writeFrames(audioData, count: count)
            }
        }
    }
}
