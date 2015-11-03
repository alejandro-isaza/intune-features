//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction

class FeaturesViewController: NSTabViewController {
    var example = Example() {
        didSet {
            spectrum.example = example
        }
    }

    var spectrum: SpectrumViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.translatesAutoresizingMaskIntoConstraints = false
        tabView.translatesAutoresizingMaskIntoConstraints = false

        spectrum = storyboard!.instantiateControllerWithIdentifier("SpectrumViewController") as! SpectrumViewController
        tabViewItems = [ NSTabViewItem(viewController: spectrum) ]
    }
    
}
