//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction

class FeaturesViewController: NSTabViewController {
    var example = Example() {
        didSet {
            spectrum.example = example
            peakHeights.example = example
        }
    }

    var spectrum: SpectrumViewController!
    var peakHeights: PeakHeightsViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.translatesAutoresizingMaskIntoConstraints = false
        tabView.translatesAutoresizingMaskIntoConstraints = false

        spectrum = storyboard!.instantiateControllerWithIdentifier("SpectrumViewController") as! SpectrumViewController
        peakHeights = storyboard!.instantiateControllerWithIdentifier("PeakHeightsViewController") as! PeakHeightsViewController
        tabViewItems = [
            NSTabViewItem(viewController: spectrum),
            NSTabViewItem(viewController: peakHeights)
        ]
    }
    
}
