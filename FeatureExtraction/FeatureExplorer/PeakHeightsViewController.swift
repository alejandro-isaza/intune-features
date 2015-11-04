//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class PeakHeightsViewController: NSViewController {
    @IBOutlet weak var plotView: PlotView?

    var example = Example() {
        didSet {
            updateView()
        }
    }

    let feature: PeakHeightsFeature = PeakHeightsFeature(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)

    // Helpers
    let window: RealArray = {
        let array = RealArray(count: Configuration.sampleCount)
        vDSP_hamm_windowD(array.mutablePointer, vDSP_Length(Configuration.sampleCount), 0)
        return array
    }()
    let fft = FFT(inputLength: Configuration.sampleCount)
    let peakExtractor = PeakExtractor(heightCutoffMultiplier: Configuration.peakHeightCutoffMultiplier, minimumNoteDistance: Configuration.peakMinimumNoteDistance)
    let fb = Double(Configuration.sampleRate) / Double(Configuration.sampleCount)

    override func viewDidLoad() {
        super.viewDidLoad()

        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Fit(3)))
        plotView!.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
        updateView()
    }

    func updateView() {
        if example.data.1.count < Configuration.sampleCount {
            return
        }
        guard let plotView = plotView else {
            return
        }
        plotView.removeAllPointSets()

        let rms = rmsq(example.data.1)
        let spectrum = spectrumValues(example.data.1)
        let specPoints = spectrumPoints(spectrum)
        let peaks = peakExtractor.process(specPoints, rms: rms).sort{ $0.y > $1.y }
        feature.update(peaks, rms: rms)

        var points = Array<PlotKit.Point>()
        for band in 0..<feature.peakHeights.count {
            let note = feature.noteForBand(band)
            points.append(PlotKit.Point(x: note, y: feature.peakHeights[band]))
        }
        let pointSet = PointSet(points: points)
        plotView.addPointSet(pointSet)
    }

    /// Compute the power spectrum values
    func spectrumValues(data: RealArray) -> RealArray {
        return sqrt(fft.forwardMags(data * window))
    }

    /// Convert from spectrum values to frequency, value points
    func spectrumPoints(spectrum: RealArray) -> [FeatureExtraction.Point] {
        return (0..<spectrum.count).map{ FeatureExtraction.Point(x: fb * Real($0), y: spectrum[$0]) }
    }
}
