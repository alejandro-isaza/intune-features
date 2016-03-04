//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class SpectrumViewController: BandsFeaturesViewController {
    var configuration: Configuration?

    override func viewDidLoad() {
        super.viewDidLoad()

        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Fit(3)))
        plotView!.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
    }

    func updateView(feature: Feature, markNotes: [Int]) {
        if !viewLoaded {
            return
        }
        guard let configuration = configuration else {
            return
        }
        guard let plotView = plotView else {
            return
        }

        plotView.removeAllPlots()
        plotView.fixedXInterval = Double(configuration.spectrumNoteRange.startIndex)...Double(configuration.spectrumNoteRange.endIndex)

        var maxY: Double = 0
        var points = Array<PlotKit.Point>()
        for band in 0..<configuration.spectrumNoteRange.count {
            let note = configuration.spectrumNoteRange.startIndex + band
            let y = Double(feature.spectrum[band])
            points.append(Point(x: Double(note), y: y))

            if y > maxY {
                maxY = y
            }
        }
        let pointSet = PointSet(points: points)
        pointSet.lineColor = lineColor
        plotView.addPointSet(pointSet)

        // Markers
        var markPoints = Array<PlotKit.Point>()
        for note in markNotes {
            markPoints.append(Point(x: Double(note), y: 0))
            markPoints.append(Point(x: Double(note), y: maxY))
            markPoints.append(Point(x: Double(note), y: 0))
        }
        let markPointSet = PointSet(points: markPoints)
        markPointSet.pointColor = markerColor
        plotView.addPointSet(markPointSet)
    }
}
