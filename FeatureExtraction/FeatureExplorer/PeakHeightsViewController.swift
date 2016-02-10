//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class PeakHeightsViewController: BandsFeaturesViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Fit(3)))
        plotView!.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
        plotView!.fixedXInterval = Double(FeatureBuilder.bandNotes.startIndex)...Double(FeatureBuilder.bandNotes.endIndex)
    }

    func updateView(feature: Feature, markNotes: [Int]) {
        _ = view // Force the view to load
        guard let plotView = plotView else {
            return
        }
        plotView.clear()

        var maxY: Double = 0
        var points = Array<PlotKit.Point>()
        for band in 0..<feature.peakHeights.count {
            let note = Double(FeatureBuilder.bandNotes.startIndex + band)
            let y = Double(feature.peakHeights[band])
            points.append(PlotKit.Point(x: note, y: y))

            if y > maxY {
                maxY = y
            }
        }
        let pointSet = PointSet(points: points)
        pointSet.color = lineColor
        plotView.addPointSet(pointSet)

        // Markers
        var markPoints = Array<PlotKit.Point>()
        for note in markNotes {
            markPoints.append(Point(x: Double(note), y: 0))
            markPoints.append(Point(x: Double(note), y: maxY))
            markPoints.append(Point(x: Double(note), y: 0))
        }
        let markPointSet = PointSet(points: markPoints)
        markPointSet.color = markerColor
        plotView.addPointSet(markPointSet)
    }
}
