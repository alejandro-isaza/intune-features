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
    var peakLocations: PeakLocationsViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.translatesAutoresizingMaskIntoConstraints = false
        tabView.translatesAutoresizingMaskIntoConstraints = false
        
        spectrum = storyboard!.instantiateControllerWithIdentifier("SpectrumViewController") as! SpectrumViewController
        peakHeights = storyboard!.instantiateControllerWithIdentifier("PeakHeightsViewController") as! PeakHeightsViewController
        peakLocations = storyboard!.instantiateControllerWithIdentifier("PeakLocationsViewController") as! PeakLocationsViewController
        tabViewItems = [
            NSTabViewItem(viewController: spectrum),
            NSTabViewItem(viewController: peakHeights),
            NSTabViewItem(viewController: peakLocations)
        ]
        // Load all views
        selectedTabViewItemIndex = 0
    }

    // MARK: - Feature extraction

    let window: RealArray = {
        let array = RealArray(count: Configuration.sampleCount)
        vDSP_hamm_windowD(array.mutablePointer, vDSP_Length(Configuration.sampleCount), 0)
        return array
    }()
    let fft = FFT(inputLength: Configuration.sampleCount)
    let peakExtractor = PeakExtractor(heightCutoffMultiplier: Configuration.peakHeightCutoffMultiplier, minimumNoteDistance: Configuration.peakMinimumNoteDistance)
    let fb = Double(Configuration.sampleRate) / Double(Configuration.sampleCount)

    /// Compute the power spectrum values
    func spectrumValues(data: RealArray) -> RealArray {
        return sqrt(fft.forwardMags(data * window))
    }

    /// Convert from spectrum values to frequency, value points
    func spectrumPoints(spectrum: RealArray) -> [FeatureExtraction.Point] {
        return (0..<spectrum.count).map{ FeatureExtraction.Point(x: fb * Real($0), y: spectrum[$0]) }
    }

    func updateFeatures() {
        let rms = rmsq(example.data.1)
        let spec = spectrumValues(example.data.1)
        let specPoints = spectrumPoints(spec)
        let peaks = peakExtractor.process(specPoints, rms: rms).sort{ $0.y > $1.y }
        let markNotes = notes.map{ Int($0.note) }

        spectrum.updateView(spec, baseFrequency: fb, markNotes: markNotes)
        peakHeights.updateView(peaks, rms: rms, markNotes: markNotes)
        peakLocations.updateView(peaks, markNotes: markNotes)
    }
    
}
