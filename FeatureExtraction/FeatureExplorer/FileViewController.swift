//  Copyright © 2015 Venture Media. All rights reserved.

import AudioToolbox
import Cocoa
import FeatureExtraction
import Peak
import Upsurge

class FileViewController: NSViewController {
    var configuration: Configuration! {
        didSet {
            updateConfiguration()
        }
    }

    var example: Example?
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

        if configuration != nil {
            updateConfiguration()
        }

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

    func updateConfiguration() {
        offsetStepper.minValue = Double(configuration.windowSize/2 + configuration.stepSize)
        offsetStepper.increment = Double(configuration.stepSize)
        offsetStepper.maxValue = DBL_MAX
        offsetSlider.minValue = Double(configuration.windowSize/2 + configuration.stepSize)
        offsetSlider.maxValue = DBL_MAX

    }

    func loadExample(filePath: String) {
        fileNameTextField.stringValue = ""
        offsetTextView.integerValue = 0
        offsetStepper.integerValue = 0
        offsetSlider.integerValue = 0
        rmsTextField.stringValue = ""
        notesTextField.stringValue = ""

        var example = Example(dataSize: configuration.windowSize + configuration.stepSize)
        example.filePath = filePath
        self.example = example

        let midiFilePath = (filePath as NSString).stringByDeletingPathExtension + ".mid"
        midiFile = MIDIFile(filePath: midiFilePath)

        audioFile = AudioFile.open(example.filePath)
        loadOffset(configuration.windowSize)
    }

    func loadOffset(var offset: Int) {
        guard let audioFile = audioFile else {
            print("Failed to open file '\(example!.filePath)'")
            return
        }
        offsetStepper.maxValue = Double(audioFile.frameCount - configuration.windowSize/2)
        offsetSlider.maxValue = Double(audioFile.frameCount - configuration.windowSize/2)

        if offset < configuration.windowSize/2 + configuration.stepSize {
            offset = configuration.windowSize/2 + configuration.stepSize
        }
        example!.frameOffset = offset

        audioFile.currentFrame = offset
        withPointer(&example!.data) { pointer in
            audioFile.readFrames(pointer, count: configuration.windowSize + configuration.stepSize)
        }

        featuresViewController.example = example

        fileNameTextField.stringValue = example!.filePath
        offsetTextView.integerValue = example!.frameOffset
        offsetStepper.integerValue = example!.frameOffset
        offsetSlider.integerValue = example!.frameOffset
        rmsTextField.doubleValue = rmsq(example!.data)

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
        let timeStart = Double(offset - configuration.windowSize/2) / audioFile.sampleRate
        let timeEnd = Double(offset + configuration.windowSize/2) / audioFile.sampleRate
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
            if abs(noteStartTime - time) <= 0.25 {
                notes.append(note)
            }
        }

        return notes
    }
}
