//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

public class FeatureData {
    public let exampleCount: Int
    public internal(set) var labels: [Int]
    public internal(set) var data: [String: [Double]]

    init(exampleCount: Int) {
        self.exampleCount = exampleCount

        labels = [Int]()
        labels.reserveCapacity(exampleCount)

        data = [String: [Double]]()
    }

    public convenience init(features: [Example: [String: Feature]]) {
        self.init(exampleCount: features.count)

        var shuffledExamples = [Example](features.keys)
        shuffledExamples.shuffleInPlace()

        for example in shuffledExamples {
            labels.append(example.label)

            let features = features[example]!
            for (name, feature) in features {
                var featureData: [Double]
                if let data = data[name] {
                    featureData = data
                } else {
                    featureData = [Double]()
                    featureData.reserveCapacity(feature.dynamicType.size() * exampleCount)
                }
                featureData.appendContentsOf(feature.serialize())
                data.updateValue(featureData, forKey: name)
            }
        }
    }
}

public func serializeFeatures(features: [String: Feature]) -> [String: [Double]] {
    var data = [String: [Double]]()

    for (name, feature) in features {
        data[name] = [Double](feature.serialize())
    }
    return data
}
