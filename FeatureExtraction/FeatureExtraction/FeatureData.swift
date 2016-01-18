//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class FeatureData {
    public var filePath: String
    public var fileOffset: Int
    public var label: Label
    public var feature: Feature
    
    public init(filePath: String, fileOffset: Int, label: Label) {
        self.filePath = filePath
        self.fileOffset = fileOffset
        self.label = label
        self.feature = Feature()
    }

    public init(filePath: String, fileOffset: Int, label: Label, feature: Feature) {
        self.filePath = filePath
        self.fileOffset = fileOffset
        self.label = label
        self.feature = feature
    }
}
