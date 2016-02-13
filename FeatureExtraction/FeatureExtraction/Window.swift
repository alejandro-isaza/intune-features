//  Copyright © 2016 Venture Media. All rights reserved.

import Foundation

public struct Window {
    /// The start offset of the window in samples
    public var start: Int

    /// The window label
    public var label: Label

    /// The window features
    public var feature: Feature

    public init(start: Int, label: Label, feature: Feature) {
        self.start = start
        self.label = label
        self.feature = feature
    }

    public init(start: Int) {
        self.start = start
        self.label = Label()
        self.feature = Feature()
    }
}
