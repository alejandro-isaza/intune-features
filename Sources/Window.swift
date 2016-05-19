// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

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

    public init(start: Int, noteCount: Int, bandCount: Int) {
        self.start = start
        self.label = Label(noteCount: noteCount)
        self.feature = Feature(bandCount: bandCount)
    }
}
