//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class FeatureData {
    public var filePath: String
    public var fileOffset: Int
    public var label: [Int]
    public var features = [String: RealArray]()
    
    public init(filePath: String, fileOffset: Int, label: [Int]) {
        self.filePath = filePath
        self.fileOffset = fileOffset
        self.label = label
    }

    public init(filePath: String, fileOffset: Int, label: [Int], features: [String: RealArray]) {
        self.filePath = filePath
        self.fileOffset = fileOffset
        self.label = label
        self.features = features
    }
}
