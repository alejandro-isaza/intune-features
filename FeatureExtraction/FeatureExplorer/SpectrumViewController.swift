//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class SpectrumViewController: NSViewController {
    @IBOutlet weak var plotView: PlotView!

    var example = Example() {
        didSet {
            updateView()
        }
    }

    let feature: SpectrumFeature = SpectrumFeature(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)

    // Helpers
    let window = RealArray(count: Configuration.sampleCount)
    let fft = FFT(inputLength: Configuration.sampleCount)
    let fb = Double(Configuration.sampleRate) / Double(Configuration.sampleCount)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        plotView.addAxis(Axis(orientation: .Vertical, ticks: .Fit(3)))
        plotView.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
    }

    func updateView() {
        plotView.removeAllPointSets()
        
        let spectrum = spectrumValues(example.data.1)
        feature.update(spectrum: spectrum, baseFrequency: fb)

        var points = Array<PlotKit.Point>()
        for band in 0..<feature.bands.count {
            let note = feature.noteForBand(band)
            points.append(Point(x: note, y: feature.bands[band]))
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
