//  Copyright © 2015 Venture Media. All rights reserved.

import UIKit

class ViewController: UIViewController {
    let net = MonophonicNet()

    @IBOutlet weak var exampleIndexTextField: UITextField!
    @IBOutlet weak var actualLabelTextField: UITextField!
    @IBOutlet var labelTextFields: [UITextField]!
    @IBOutlet var valueTextFields: [UITextField]!
    @IBOutlet weak var timeTextField: UITextField!

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
}

