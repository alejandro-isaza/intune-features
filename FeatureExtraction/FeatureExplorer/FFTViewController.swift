//  Copyright © 2015 Venture Media. All rights reserved.

import Cocoa
import FeatureExtraction
import PlotKit
import Upsurge

class FFTViewController: BandsFeaturesViewController {
    var configuration: Configuration?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        plotView!.addAxis(Axis(orientation: .Vertical, ticks: .Fit(3)))
        plotView!.addAxis(Axis(orientation: .Horizontal, ticks: .Distance(12)))
    }
    
    func updateView(points: [PlotKit.Point]) {
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

        let pointSet = PointSet(points: points)
        pointSet.lineColor = lineColor
        plotView.addPointSet(pointSet)
    }
}
