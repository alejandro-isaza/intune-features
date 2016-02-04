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
    var spectrumFlux: SpectrumFluxViewController!
    var spectrumFeature = SpectrumFeature(notes: FeatureBuilder.bandNotes, bandSize: FeatureBuilder.bandSize)

    override func viewDidLoad() {
        super.viewDidLoad()

        view.translatesAutoresizingMaskIntoConstraints = false
        tabView.translatesAutoresizingMaskIntoConstraints = false
        
        spectrum = storyboard!.instantiateControllerWithIdentifier("SpectrumViewController") as! SpectrumViewController
        peakHeights = storyboard!.instantiateControllerWithIdentifier("PeakHeightsViewController") as! PeakHeightsViewController
        peakLocations = storyboard!.instantiateControllerWithIdentifier("PeakLocationsViewController") as! PeakLocationsViewController
        spectrumFlux = storyboard!.instantiateControllerWithIdentifier("SpectrumFluxViewController") as! SpectrumFluxViewController
        tabViewItems = [
            NSTabViewItem(viewController: spectrum),
            NSTabViewItem(viewController: peakHeights),
            NSTabViewItem(viewController: peakLocations),
            NSTabViewItem(viewController: spectrumFlux)
        ]
        selectedTabViewItemIndex = 0
    }

    // MARK: - Feature extraction

    let window: ValueArray<Double> = {
        let array = ValueArray<Double>(count: FeatureBuilder.windowSize)
        vDSP_hamm_windowD(array.mutablePointer, vDSP_Length(FeatureBuilder.windowSize), 0)
        return array
    }()
    let fft = FFT(inputLength: FeatureBuilder.windowSize)
    let peakExtractor = PeakExtractor(heightCutoffMultiplier: FeatureBuilder.peakHeightCutoffMultiplier, minimumNoteDistance: FeatureBuilder.peakMinimumNoteDistance)
    let fb = Double(FeatureBuilder.samplingFrequency) / Double(FeatureBuilder.windowSize)

    /// Compute the power spectrum values
    func spectrumValues(data: ValueArray<Double>) -> ValueArray<Double> {
        return sqrt(fft.forwardMags(data * window))
    }

    /// Convert from spectrum values to frequency, value points
    func spectrumPoints(spectrum: ValueArray<Double>) -> [FeatureExtraction.Point] {
        return (0..<spectrum.count).map{ FeatureExtraction.Point(x: fb * Real($0), y: spectrum[$0]) }
    }

    func updateFeatures() {
        let spec0 = spectrumValues(example.data.0)
        spectrumFeature.update(spectrum: spec0, baseFrequency: fb)

        let rms = rmsq(example.data.1)
        let spec = spectrumValues(example.data.1)
        let specPoints = spectrumPoints(spec)
        let peaks = peakExtractor.process(specPoints, rms: rms).sort{ $0.y > $1.y }
        let markNotes = notes.map{ Int($0.note) }

        spectrum.updateView(spec, baseFrequency: fb, markNotes: markNotes)
        peakHeights.updateView(peaks, rms: rms, markNotes: markNotes)
        peakLocations.updateView(peaks, markNotes: markNotes)
        spectrumFlux.updateView(spectrum0: spectrumFeature.data, spectrum1: spectrum.feature.data, markNotes: markNotes)
    }
    
}
