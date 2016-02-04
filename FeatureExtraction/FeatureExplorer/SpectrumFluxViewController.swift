//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class SpectrumFluxViewController: BandsFeaturesViewController {
    let yrange = -0.1...0.1
    let feature: SpectrumFluxFeature = SpectrumFluxFeature(notes: FeatureBuilder.bandNotes, bandSize: FeatureBuilder.bandSize)

    override func viewDidLoad() {
        super.viewDidLoad()

        plotView!.fixedYInterval = yrange
        plotView!.fixedXInterval = Double(FeatureBuilder.bandNotes.startIndex)...Double(FeatureBuilder.bandNotes.endIndex)
        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Distance(0.05)))

        var haxis = Axis(orientation: .Horizontal, ticks: .Distance(12))
        haxis.position = .Value(0.0)
        plotView!.addAxis(haxis)

    }

    func updateView(spectrum0 spectrum0: ValueArray<Double>, spectrum1: ValueArray<Double>, markNotes: [Int]) {
        _ = view // Force the view to load
        guard let plotView = plotView else {
            return
        }
        plotView.clear()

        feature.update(spectrum0: spectrum0, spectrum1: spectrum1)

        var points = Array<PlotKit.Point>()
        for band in 0..<feature.fluxes.count {
            let note = feature.noteForBand(band)
            let y = feature.fluxes[band]
            points.append(Point(x: note, y: y))
        }
        let pointSet = PointSet(points: points)
        pointSet.color = lineColor
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
        markPointSet.color = markerColor
        plotView.addPointSet(markPointSet)
    }
}
