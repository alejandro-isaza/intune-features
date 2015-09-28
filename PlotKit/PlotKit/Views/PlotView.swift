//  Copyright © 2015 Venture Media Labs. All rights reserved.

import Foundation

public class PlotView : NSView {
    struct Constants {
        static let hPadding = CGFloat(60)
        static let vPadding = CGFloat(40)
    }

    var axesView = AxesView()
    var pointSetViews = [PointSetView]()

    public var backgroundColor: NSColor = NSColor.whiteColor()

    /// If not `nil` the x values are limited to this interval, otherwise the x interval will fit all values
    public var fixedXInterval: Interval? {
        didSet {
            updateIntervals()
        }
    }

    /// If not `nil` the y values are limited to this interval, otherwise the y interval will fit all values
    public var fixedYInterval: Interval? {
        didSet {
            updateIntervals()
        }
    }

    /// The x-range that fits all the point sets in the plot
    public var fittingXInterval: Interval {
        var interval = Interval.empty
        for view in pointSetViews {
            interval = join(interval, view.pointSet.xInterval)
        }
        return interval
    }

    /// The y-range that fits all the point sets in the plot
    public var fittingYInterval: Interval {
        var interval = Interval.empty
        for view in pointSetViews {
            interval = join(interval, view.pointSet.yInterval)
        }
        return interval
    }

    public func addPointSet(pointSet: PointSet) {
        let view = PointSetView(pointSet: pointSet)

        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)

        let views = ["view": view]
        let metrics = [
            "hPadding": Constants.hPadding,
            "vPadding": Constants.vPadding
        ]
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-(hPadding)-[view]-(hPadding)-|",
            options: .AlignAllCenterY, metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-(vPadding)-[view]-(vPadding)-|",
            options: .AlignAllCenterX, metrics: metrics, views: views))

        pointSetViews.append(view)
        updateIntervals()
    }


    // MARK: - Helper functions

    var xInterval: Interval {
        if let interval = fixedXInterval {
            return interval
        }
        return fittingXInterval
    }

    var yInterval: Interval {
        if let interval = fixedYInterval {
            return interval
        }
        return fittingYInterval
    }

    func setupAxesView() {
        axesView.translatesAutoresizingMaskIntoConstraints = false
        axesView.insets = NSEdgeInsets(
            top: Constants.vPadding,
            left: Constants.hPadding,
            bottom: Constants.vPadding,
            right: Constants.hPadding)
        addSubview(axesView)

        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[view]|", options: .AlignAllCenterY, metrics: nil, views: ["view": axesView]))
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[view]|", options: .AlignAllCenterX, metrics: nil, views: ["view": axesView]))
    }

    func updateIntervals() {
        for view in pointSetViews {
            view.xInterval = xInterval
            view.yInterval = yInterval
        }

        updateAxes()
    }

    func updateAxes() {
        let xint = xInterval
        axesView.xInterval = xint
        axesView.xTicks = [
            TickMark(xint.min),
            TickMark((xint.max + xint.min) / 2),
            TickMark(xint.max)
        ]

        let yint = yInterval
        axesView.yInterval = yint
        axesView.yTicks = [
            TickMark(yint.min),
            TickMark((yint.max + yint.min) / 2),
            TickMark(yint.max)
        ]
    }


    // MARK: - NSView overrides

    public override init(frame: NSRect) {
        super.init(frame: frame)
        setupAxesView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAxesView()
    }

    public override var opaque: Bool {
        return true
    }

    override public func drawRect(rect: CGRect) {
        backgroundColor.setFill()
        NSRectFill(rect)
    }
}
