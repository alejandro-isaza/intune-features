//  Copyright © 2015 Venture Media. All rights reserved.

import AudioToolbox
import Cocoa
import FeatureExtraction
import Peak
import Upsurge

class FileViewController: NSViewController {
    var example = Example()
    var audioFile: AudioFile?
    var midiFile: MIDIFile?

    @IBOutlet weak var fileNameTextField: NSTextField!
    @IBOutlet weak var offsetTextView: NSTextField!
    @IBOutlet weak var offsetStepper: NSStepper!
    @IBOutlet weak var offsetSlider: NSSlider!
    @IBOutlet weak var rmsTextField: NSTextField!
    @IBOutlet weak var notesTextField: NSTextField!
    @IBOutlet weak var contentView: NSView!
    var featuresViewController: FeaturesViewController!

    @IBAction func offsetDidChange(control: NSControl) {
        offsetTextView.integerValue = control.integerValue
        loadOffset(control.integerValue)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserverForName(NSOutlineViewSelectionDidChangeNotification, object: nil, queue: nil, usingBlock: { notification in })

        offsetStepper.minValue = Double(FeatureBuilder.windowSize/2 + FeatureBuilder.stepSize)
        offsetStepper.increment = Double(FeatureBuilder.stepSize)
        offsetStepper.maxValue = DBL_MAX
        offsetSlider.minValue = Double(FeatureBuilder.windowSize/2 + FeatureBuilder.stepSize)
        offsetSlider.maxValue = DBL_MAX

        featuresViewController = storyboard!.instantiateControllerWithIdentifier("FeaturesViewController") as! FeaturesViewController
        addChildViewController(featuresViewController)

        let featuresView = featuresViewController.view
        featuresView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(featuresView)
        featuresView.leadingAnchor.constraintEqualToAnchor(contentView.leadingAnchor).active = true
        featuresView.trailingAnchor.constraintEqualToAnchor(contentView.trailingAnchor).active = true
        featuresView.topAnchor.constraintEqualToAnchor(contentView.topAnchor).active = true
        featuresView.bottomAnchor.constraintEqualToAnchor(contentView.bottomAnchor).active = true
    }

    func loadExample(filePath: String) {
        fileNameTextField.stringValue = ""
        offsetTextView.integerValue = 0
        offsetStepper.integerValue = 0
        offsetSlider.integerValue = 0
        rmsTextField.stringValue = ""
        notesTextField.stringValue = ""

        example.filePath = filePath
        let midiFilePath = (filePath as NSString).stringByDeletingPathExtension + ".mid"
        midiFile = MIDIFile(filePath: midiFilePath)

        audioFile = AudioFile.open(example.filePath)
        example.data.0 = ValueArray<Double>(count: FeatureBuilder.windowSize)
        example.data.1 = ValueArray<Double>(count: FeatureBuilder.windowSize)
        loadOffset(FeatureBuilder.windowSize)
    }

    func loadOffset(var offset: Int) {
        guard let audioFile = audioFile else {
            print("Failed to open file '\(example.filePath)'")
            return
        }
        offsetStepper.maxValue = Double(audioFile.frameCount - FeatureBuilder.windowSize/2)
        offsetSlider.maxValue = Double(audioFile.frameCount - FeatureBuilder.windowSize/2)

        if offset < FeatureBuilder.windowSize/2 + FeatureBuilder.stepSize {
            offset = FeatureBuilder.windowSize/2 + FeatureBuilder.stepSize
        }
        example.frameOffset = offset

        audioFile.currentFrame = offset - FeatureBuilder.windowSize/2 - FeatureBuilder.stepSize
        audioFile.readFrames(example.data.0.mutablePointer, count: FeatureBuilder.windowSize)

        audioFile.currentFrame = offset - FeatureBuilder.windowSize/2
        audioFile.readFrames(example.data.1.mutablePointer, count: FeatureBuilder.windowSize)

        featuresViewController.example = example

        fileNameTextField.stringValue = example.filePath
        offsetTextView.integerValue = example.frameOffset
        offsetStepper.integerValue = example.frameOffset
        offsetSlider.integerValue = example.frameOffset
        rmsTextField.doubleValue = rmsq(example.data.1)

        let notes = noteEventsAtOffset(offset)
        var notesString = ""
        for note in notes {
            let time = midiFile!.secondsForBeats(note.timeStamp)
            let currentTime = Double(offset) / audioFile.sampleRate
            let string = String(format: "%i (v: %i, t: %.0fms) ", arguments: [note.note, note.velocity, 1000 * (time - currentTime)])
            notesString += string
        }
        featuresViewController.notes = notes
        notesTextField.stringValue = notesString
    }

    func noteEventsAtOffset(offset: Int) -> [MIDINoteEvent] {
        guard let audioFile = audioFile, midiFile = midiFile else {
            return []
        }
        let time = Double(offset) / audioFile.sampleRate
        let timeStart = Double(offset - FeatureBuilder.windowSize/2) / audioFile.sampleRate
        let timeEnd = Double(offset + FeatureBuilder.windowSize/2) / audioFile.sampleRate
        let beatStart = midiFile.beatsForSeconds(timeStart)
        let beatEnd = midiFile.beatsForSeconds(timeEnd)

        let noteEvents = midiFile.noteEvents
        var notes = [MIDINoteEvent]()
        for note in noteEvents {
            let noteStart = note.timeStamp
            if noteStart >= beatEnd {
                break
            }

            let noteEnd = note.timeStamp + MusicTimeStamp(note.duration)
            if noteEnd < beatStart {
                continue
            }

            let noteStartTime = midiFile.secondsForBeats(noteStart)
            if abs(noteStartTime - time) <= FeatureBuilder.maxNoteLag {
                notes.append(note)
            }
        }

        return notes
    }
}
