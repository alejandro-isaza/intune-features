//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class FeatureData {
    public var example: Example
    public var features = [String: RealArray]()
    
    public init(example: Example) {
        self.example = example
    }

    public init(example: Example, features: [String: RealArray]) {
        self.example = example
        self.features = features
    }
}