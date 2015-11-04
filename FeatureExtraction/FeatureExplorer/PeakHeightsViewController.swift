//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class PeakHeightsViewController: NSViewController {
    @IBOutlet weak var plotView: PlotView?

    let feature: PeakHeightsFeature = PeakHeightsFeature(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)

    override func viewDidLoad() {
        super.viewDidLoad()

        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Fit(3)))
        plotView!.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
    }

    func updateView(peaks: [FeatureExtraction.Point], rms: Double) {
        guard let plotView = plotView else {
            return
        }
        plotView.removeAllPointSets()

        feature.update(peaks, rms: rms)

        var points = Array<PlotKit.Point>()
        for band in 0..<feature.peakHeights.count {
            let note = feature.noteForBand(band)
            points.append(PlotKit.Point(x: note, y: feature.peakHeights[band]))
        }
        let pointSet = PointSet(points: points)
        plotView.addPointSet(pointSet)
    }
}
