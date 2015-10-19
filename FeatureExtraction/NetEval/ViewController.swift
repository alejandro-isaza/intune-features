//  Copyright © 2015 Venture Media. All rights reserved.

import UIKit

class ViewController: UIViewController {
    let net = MonophonicNet()

    @IBOutlet weak var exampleIndexTextField: UITextField!
    @IBOutlet weak var actualLabelTextField: UITextField!
    @IBOutlet var labelTextFields: [UITextField]!
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
        let label = net.labels[Int(sender.value)]
        actualLabelTextField.text = String(format: "%.0f", arguments: [label])
    }

    @IBAction func run() {
        guard let index = Int(exampleIndexTextField.text!) else {
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let label = net.labels[index]
        actualLabelTextField.text = String(format: "%.0f", arguments: [label])

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
            valueTextFields[i].text = sortedValues[i].1.description
        }
    }

    @IBAction func runAll() {
        activityIndicator.startAnimating()
        let startTime = CFAbsoluteTimeGetCurrent()

        let exampleCount = net.labels.count
        var matches = 0
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            for index in 0..<exampleCount {
                let label = self.net.labels[index]
                let result = self.net.run(index)
                let (match, _) = maxi(result)!
                if match == Int(label) {
                    matches += 1
                }
            }

            dispatch_async(dispatch_get_main_queue()) {
                self.updateAllMatches(startTime, matches: matches)
            }
        }
    }

    func updateAllMatches(startTime: CFAbsoluteTime, matches: Int) {
        let exampleCount = net.labels.count
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let timePerExample = timeElapsed / Double(exampleCount)

        self.allMatchesTimeTextField.text = String(format: "%.3fs – %.3fs/example", arguments: [timeElapsed, timePerExample])

        let percent = matches * 100 / exampleCount
        self.allMatchesLabel.text = "Matched \(matches) of \(exampleCount) (\(percent)%)"

        self.activityIndicator.stopAnimating()
    }
}

