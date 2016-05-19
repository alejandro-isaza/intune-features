// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Upsurge

public protocol FeatureGenerator {
    /// Serialize the feature
    var data: ValueArray<Double> { get }

    /// Reset the internal state of the generator when there is a discontunuity in the data stream
    func reset()
}
