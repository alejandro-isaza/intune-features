//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

public struct Example: Hashable {
    public let filePath: String
    public let frameOffset: Int
    public let label: Int
    public let data: ([Double], [Double])

    public init(filePath: String, frameOffset: Int, label: Int, data: ([Double], [Double])) {
        self.filePath = filePath
        self.frameOffset = frameOffset
        self.label = label
        self.data = data
    }

    public var hashValue: Int {
        return filePath.hash ^ frameOffset.hashValue ^ label.hashValue
    }
}

public func == (lhs: Example, rhs: Example) -> Bool {
    return
        lhs.filePath == rhs.filePath &&
        lhs.frameOffset == rhs.frameOffset &&
        lhs.label == rhs.label
}
