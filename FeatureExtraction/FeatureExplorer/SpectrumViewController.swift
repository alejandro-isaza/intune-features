//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class SpectrumViewController: NSViewController {
    @IBOutlet weak var plotView: PlotView?

    let feature: SpectrumFeature = SpectrumFeature(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Fit(3)))
        plotView!.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
    }

    func updateView(spectrum: RealArray, baseFrequency: Double) {
        guard let plotView = plotView else {
            return
        }
        plotView.clear()

        feature.update(spectrum: spectrum, baseFrequency: baseFrequency)

        var points = Array<PlotKit.Point>()
        for band in 0..<feature.bands.count {
            let note = feature.noteForBand(band)
            points.append(Point(x: note, y: feature.bands[band]))
        }
        let pointSet = PointSet(points: points)
        plotView.addPointSet(pointSet)
    }
}
