//  Copyright © 2015 Venture Media. All rights reserved.

import UIKit

class ViewController: UIViewController {
    let net = MonophonicNet()
    let startNote = 36

    @IBOutlet weak var exampleIndexTextField: UITextField!
    @IBOutlet weak var actualLabelTextField: UITextField!
    @IBOutlet weak var actualNoteTextField: UITextField!

    @IBOutlet var labelTextFields: [UITextField]!
    @IBOutlet var noteTextFields: [UITextField]!
    @IBOutlet var valueTextFields: [UITextField]!
    @IBOutlet weak var timeTextField: UITextField!

    @IBOutlet weak var allMatchesLabel: UILabel!
    @IBOutlet weak var allMatchesTimeTextField: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func changeIndex(sender: UIStepper) {
        exampleIndexTextField.text = String(format: "%.0f", arguments: [sender.value])

        let label = Int(net.labels[Int(sender.value)])
        actualLabelTextField.text = label.description
        actualNoteTextField.text = (label + startNote).description
    }

    @IBAction func run() {
        guard let index = Int(exampleIndexTextField.text!) else {
            return
        }

        net.net.print = true
        let startTime = CFAbsoluteTimeGetCurrent()
        let label = Int(net.labels[index])
        actualLabelTextField.text = label.description
        actualNoteTextField.text = (label + startNote).description

        let result = net.run(index)

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        timeTextField.text = "\(timeElapsed)s"

        var values = [(Int, Double)]()
        for (i, v) in result.enumerate() {
            values.append((i, v))
        }

        let sortedValues = values.sort{ $0.1 > $1.1 }
        for i in 0..<labelTextFields.count {
            labelTextFields[i].text = sortedValues[i].0.description
            noteTextFields[i].text = (sortedValues[i].0 + startNote).description
            valueTextFields[i].text = sortedValues[i].1.description
        }
    }

    @IBAction func runAll() {
        activityIndicator.startAnimating()
        let startTime = CFAbsoluteTimeGetCurrent()
        var stats = Stats(exampleCount: net.labels.count)

        net.net.print = false
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            for index in 0..<stats.exampleCount {
                let label = Int(self.net.labels[index])
                let result = self.net.run(index)
                let (match, value) = maxi(result)!
                if match == Int(label) {
                    stats.addMatch(label: label, value: value)
                } else {
                    stats.addMismatch(expectedLabel: label, actualLabel: match, value: value)
                    Swift.print("Mismatch for example \(index). Expected \(label) (\(label + self.startNote)) got \(match) (\(match + self.startNote)) with value \(value).")
                }
            }

            stats.print()

            dispatch_async(dispatch_get_main_queue()) {
                self.updateAllMatches(startTime, stats: stats)
            }
        }
    }

    func updateAllMatches(startTime: CFAbsoluteTime, stats: Stats) {
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let timePerExample = timeElapsed / Double(stats.exampleCount)

        self.allMatchesTimeTextField.text = String(format: "%.3fs – %.3fs/example", arguments: [timeElapsed, timePerExample])

        let percent = stats.accuracy * 100
        self.allMatchesLabel.text = "Matched \(stats.matches) of \(stats.exampleCount) (\(percent)%)"

        self.activityIndicator.stopAnimating()
    }
}
