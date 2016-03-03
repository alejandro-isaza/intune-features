//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class PeakHeightsFluxViewController: BandsFeaturesViewController {
    let yrange = -1.0...1.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        plotView!.fixedYInterval = yrange
        plotView!.fixedXInterval = Double(Configuration.bandNotes.startIndex)...Double(Configuration.bandNotes.endIndex)
        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Distance(0.05)))
        
        var haxis = Axis(orientation: .Horizontal, ticks: .Distance(12))
        haxis.position = .Value(0.0)
        plotView!.addAxis(haxis)
        
    }
    
    func updateView(feature: Feature, markNotes: [Int]) {
        _ = view // Force the view to load
        guard let plotView = plotView else {
            return
        }
        plotView.removeAllPlots()
        
        var points = Array<PlotKit.Point>()
        for band in 0..<feature.peakFlux.count {
            let note = Double(Configuration.bandNotes.startIndex + band)
            let y = Double(feature.peakFlux[band])
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
