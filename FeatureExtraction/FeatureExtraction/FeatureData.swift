//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class FeatureData {
    public let exampleCount: Int
    public internal(set) var labels: [Int]
    public internal(set) var data: [String: RealArray]

    init(exampleCount: Int) {
        self.exampleCount = exampleCount

        labels = [Int]()
        labels.reserveCapacity(exampleCount)

        data = [String: RealArray]()
    }

    public convenience init(features: [Example: [String: RealArray]]) {
        self.init(exampleCount: features.count)

        for example in features.keys {
            labels.append(example.label)

            let features = features[example]!
            for (name, featureData) in features {
                var allFeatureData: RealArray
                if let data = data[name] {
                    allFeatureData = data
                } else {
                    allFeatureData = RealArray(capacity: featureData.count * exampleCount)
                    data.updateValue(allFeatureData, forKey: name)
                }
                allFeatureData.append(featureData)
            }
        }
    }
}

public func serializeFeatures(features: [String: Feature]) -> [String: RealArray] {
    var data = [String: RealArray]()

    for (name, feature) in features {
        data[name] = RealArray(feature.data)
    }
    return data
}
