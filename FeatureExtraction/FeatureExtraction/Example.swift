//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public struct Example: Hashable {
    public let filePath: String
    public let frameOffset: Int
    public let label: [Int]
    public let data: (RealArray, RealArray)

    public init(filePath: String, frameOffset: Int, label: [Int], data: (RealArray, RealArray)) {
        self.filePath = filePath
        self.frameOffset = frameOffset
        self.label = label
        self.data = data
    }
    
    public init(filePath: String, frameOffset: Int, label: [Int]) {
        self.init(filePath: filePath, frameOffset: frameOffset, label: label, data: (RealArray(), RealArray()))
    }

    public var hashValue: Int {
        return filePath.hash ^ frameOffset.hashValue
    }
}

public func == (lhs: Example, rhs: Example) -> Bool {
    return
        lhs.filePath == rhs.filePath &&
        lhs.frameOffset == rhs.frameOffset &&
        lhs.label == rhs.label
}
