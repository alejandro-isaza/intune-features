//  Copyright © 2015 Venture Media. All rights reserved.

import AudioToolbox
import Cocoa
import FeatureExtraction
import Peak
import Upsurge

class FileViewController: NSViewController {
    let minOverlapTime = 0.004 // The minum note overlap in seconds to consider a note part of an example

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

        offsetStepper.minValue = Double(Configuration.sampleCount/2 + Configuration.sampleStep)
        offsetStepper.increment = Double(Configuration.sampleStep)
        offsetStepper.maxValue = DBL_MAX
        offsetSlider.minValue = Double(Configuration.sampleCount/2 + Configuration.sampleStep)
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
        example.data.0 = RealArray(count: Configuration.sampleCount)
        example.data.1 = RealArray(count: Configuration.sampleCount)
        loadOffset(Configuration.sampleCount)
    }

    func loadOffset(var offset: Int) {
        guard let audioFile = audioFile else {
            print("Failed to open file '\(example.filePath)'")
            return
        }
        offsetStepper.maxValue = Double(audioFile.frameCount - Configuration.sampleCount/2)
        offsetSlider.maxValue = Double(audioFile.frameCount - Configuration.sampleCount/2)

        if offset < Configuration.sampleCount/2 + Configuration.sampleStep {
            offset = Configuration.sampleCount/2 + Configuration.sampleStep
        }
        example.frameOffset = offset
        let overlapCount = Configuration.sampleCount - Configuration.sampleStep

        audioFile.currentFrame = offset - Configuration.sampleCount/2 - Configuration.sampleStep
        audioFile.readFrames(example.data.0.mutablePointer, count: Configuration.sampleCount)

        audioFile.currentFrame -= overlapCount
        audioFile.readFrames(example.data.1.mutablePointer, count: Configuration.sampleCount)

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
            let string = String(format: "%i (v: %i, t: %.3f) ", arguments: [note.note, note.velocity, time - currentTime])
            notesString += string
        }
        notesTextField.stringValue = notesString
    }

    func noteEventsAtOffset(offset: Int) -> [MIDINoteEvent] {
        guard let audioFile = audioFile, midiFile = midiFile else {
            return []
        }
        let timeStart = Double(offset - Configuration.sampleCount/2) / audioFile.sampleRate
        let timeEnd = Double(offset + Configuration.sampleCount/2) / audioFile.sampleRate
        let beatStart = midiFile.beatsForSeconds(timeStart)
        let beatEnd = midiFile.beatsForSeconds(timeEnd)

        let noteEvents = midiFile.noteEvents
        let beatRange = beatStart..<beatEnd

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

            let noteRange = noteStart..<noteEnd
            let overlap = noteRange.clamp(beatRange)
            let overlapTime = midiFile.secondsForBeats(overlap.end) - midiFile.secondsForBeats(overlap.start)
            if overlapTime >= minOverlapTime {
                notes.append(note)
            }
        }

        return notes
    }
}
