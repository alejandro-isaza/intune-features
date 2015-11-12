//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class PeakLocationsViewController: NSViewController {
    var lineColor = NSColor.blueColor()
    var markerColor = NSColor.grayColor()

    @IBOutlet weak var plotView: PlotView?

    let feature: PeakLocationsFeature = PeakLocationsFeature(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)

    override func viewDidLoad() {
        super.viewDidLoad()

        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Fit(3)))
        plotView!.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
    }

    func updateView(peaks: [FeatureExtraction.Point], markNotes: [Int]) {
        guard let plotView = plotView else {
            return
        }
        plotView.clear()

        feature.update(peaks)

        var points = Array<PlotKit.Point>()
        for band in 0..<feature.peakLocations.count {
            let note = feature.noteForBand(band)
            points.append(PlotKit.Point(x: note, y: feature.peakLocations[band]))
        }
        let pointSet = PointSet(points: points)
        pointSet.color = lineColor
        plotView.addPointSet(pointSet)

        // Markers
        var markPoints = Array<PlotKit.Point>()
        for note in markNotes {
            markPoints.append(Point(x: Double(note), y: 0))
            markPoints.append(Point(x: Double(note), y: 1))
            markPoints.append(Point(x: Double(note), y: 0))
        }
        let markPointSet = PointSet(points: markPoints)
        markPointSet.color = markerColor
        plotView.addPointSet(markPointSet)
    }
}
