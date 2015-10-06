//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

public class FeatureData {
    public let exampleCount: Int
    public let exampleSize: Int
    public internal(set) var labels: [Int]
    public internal(set) var data: [Double]

    init(exampleCount: Int, exampleSize: Int) {
        self.exampleCount = exampleCount
        self.exampleSize = exampleSize

        labels = [Int]()
        labels.reserveCapacity(exampleCount)

        data = [Double]()
        data.reserveCapacity(exampleCount * exampleSize)
    }

    public convenience init(features: [Example: [Feature]]) {
        let exampleSize = FeatureData.exampleSize(features)
        self.init(exampleCount: features.count, exampleSize: exampleSize)

        for (example, features) in features {
            labels.append(example.label)
            data.appendContentsOf(serializeFeatures(features))
        }
    }

    class func exampleSize(features: [Example: [Feature]]) -> Int {
        var exampleSizeOpt: Int?
        for feature in features.values {
            if let size = exampleSizeOpt {
                precondition(feature.count == size, "All feature vectors need to have the same size")
            } else {
                exampleSizeOpt = feature.count
            }
        }
        guard let exampleSize = exampleSizeOpt else {
            fatalError("Empty features")
        }
        return exampleSize
    }
}

public func serializeFeatures(features: [Feature]) -> [Double] {
    var size = 0
    for feature in features {
        size += feature.dynamicType.size()
    }

    var data = [Double]()
    data.reserveCapacity(size)

    for feature in features {
        data.appendContentsOf(feature.serialize())
    }
    return data
}
