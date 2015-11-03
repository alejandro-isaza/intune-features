//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import Peak
import Upsurge

class FileViewController: NSViewController {
    var example = Example()

    @IBOutlet weak var fileNameTextField: NSTextField!
    @IBOutlet weak var offsetTextView: NSTextField!
    @IBOutlet weak var offsetStepper: NSStepper!
    @IBOutlet weak var rmsTextField: NSTextField!
    @IBOutlet weak var contentView: NSView!
    var featuresViewController: FeaturesViewController!

    @IBAction func offsetTextFieldDidChange(textField: NSTextField) {
        loadOffset(textField.integerValue)
    }

    @IBAction func offsetStepperDidChange(stepper: NSStepper) {
        loadOffset(stepper.integerValue)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserverForName(NSOutlineViewSelectionDidChangeNotification, object: nil, queue: nil, usingBlock: { notification in })

        offsetStepper.minValue = Double(Configuration.sampleCount/2 + Configuration.sampleStep)
        offsetStepper.increment = Double(Configuration.sampleStep)
        offsetStepper.maxValue = DBL_MAX

        featuresViewController = storyboard!.instantiateControllerWithIdentifier("FeaturesViewController") as! FeaturesViewController
        addChildViewController(featuresViewController)

        let featuresView = featuresViewController.view
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
        rmsTextField.stringValue = ""

        example.filePath = filePath
        example.data.0 = RealArray(count: Configuration.sampleCount)
        example.data.1 = RealArray(count: Configuration.sampleCount)
        loadOffset(Configuration.sampleCount)
    }

    func loadOffset(var offset: Int) {
        guard let audioFile = AudioFile.open(example.filePath) else {
            print("Failed to open file '\(example.filePath)'")
            return
        }
        offsetStepper.maxValue = Double(audioFile.frameCount - Configuration.sampleCount/2)

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
        rmsTextField.doubleValue = rmsq(example.data.1)
    }
}
