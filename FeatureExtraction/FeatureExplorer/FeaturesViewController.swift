//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import Upsurge
import Peak

class FeaturesViewController: NSTabViewController {
    var example = Example() {
        didSet {
            updateFeatures()
        }
    }

    var notes = [MIDINoteEvent]() {
        didSet {
            updateFeatures()
        }
    }

    var spectrum: SpectrumViewController!
    var peakHeights: PeakHeightsViewController!
    var peakHeightsFlux: PeakHeightsFluxViewController!
    var peakLocations: PeakLocationsViewController!
    var spectrumFlux: SpectrumFluxViewController!

    var featureBuilder: FeatureBuilder!

    override func viewDidLoad() {
        super.viewDidLoad()

        featureBuilder = FeatureBuilder(windowSize: windowSize, stepSize: stepSize)

        view.translatesAutoresizingMaskIntoConstraints = false
        tabView.translatesAutoresizingMaskIntoConstraints = false
        
        spectrum = storyboard!.instantiateControllerWithIdentifier("SpectrumViewController") as! SpectrumViewController
        peakHeights = storyboard!.instantiateControllerWithIdentifier("PeakHeightsViewController") as! PeakHeightsViewController
        peakHeightsFlux = storyboard!.instantiateControllerWithIdentifier("PeakHeightsFluxViewController") as! PeakHeightsFluxViewController
        peakLocations = storyboard!.instantiateControllerWithIdentifier("PeakLocationsViewController") as! PeakLocationsViewController
        spectrumFlux = storyboard!.instantiateControllerWithIdentifier("SpectrumFluxViewController") as! SpectrumFluxViewController
        tabViewItems = [
            NSTabViewItem(viewController: spectrum),
            NSTabViewItem(viewController: peakHeights),
            NSTabViewItem(viewController: peakHeightsFlux),
            NSTabViewItem(viewController: peakLocations),
            NSTabViewItem(viewController: spectrumFlux)
        ]
        selectedTabViewItemIndex = 0
    }

    /// Convert from spectrum values to frequency, value points
    func spectrumPoints(spectrum: ValueArray<Double>) -> [FeatureExtraction.Point] {
        return (0..<spectrum.count).map{ FeatureExtraction.Point(x: featureBuilder.baseFrequency * Double($0), y: spectrum[$0]) }
    }

    func updateFeatures() {
        let feature = featureBuilder.generateFeatures(example.data[0..<featureBuilder.windowSize], example.data[featureBuilder.stepSize..<featureBuilder.windowSize + featureBuilder.stepSize])

        let markNotes = notes.map{ Int($0.note) }

        spectrum.updateView(feature, markNotes: markNotes)
        peakHeights.updateView(feature, markNotes: markNotes)
        peakHeightsFlux.updateView(feature, markNotes: markNotes)
        peakLocations.updateView(feature, markNotes: markNotes)
        spectrumFlux.updateView(feature, markNotes: markNotes)
    }
    
}
