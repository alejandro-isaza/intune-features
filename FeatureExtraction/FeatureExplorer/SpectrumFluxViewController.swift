//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class SpectrumFluxViewController: BandsFeaturesViewController {
    var configuration: Configuration?
    let yrange = -1.0...1.0

    override func viewDidLoad() {
        super.viewDidLoad()

        plotView!.fixedYInterval = yrange
        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Distance(0.05)))

        var haxis = Axis(orientation: .Horizontal, ticks: .Distance(12))
        haxis.position = .Value(0.0)
        plotView!.addAxis(haxis)

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

        var points = Array<PlotKit.Point>()
        for band in 0..<feature.spectralFlux.count {
            let note = Double(configuration.spectrumNoteRange.startIndex + band)
            let y = Double(feature.spectralFlux[band])
            points.append(Point(x: note, y: y))
        }
        let pointSet = PointSet(points: points)
        pointSet.lineColor = lineColor
        plotView.addPointSet(pointSet)

        // Markers
        var markPoints = Array<PlotKit.Point>()
        for note in markNotes {
            markPoints.append(Point(x: Double(note), y: 0))
            markPoints.append(Point(x: Double(note), y: yrange.end))
            markPoints.append(Point(x: Double(note), y: yrange.start))
            markPoints.append(Point(x: Double(note), y: 0))
        }
        let markPointSet = PointSet(points: markPoints)
        markPointSet.pointColor = markerColor
        plotView.addPointSet(markPointSet)
    }
}
