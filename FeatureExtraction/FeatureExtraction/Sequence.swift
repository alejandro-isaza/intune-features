//  Copyright © 2016 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public class Sequence {
    public enum Error: ErrorType {
        case DatasetNotFound
        case DatasetNotCompatible
    }

    public class Event {
        public var offset: Int
        public var notes: [Note]
        public var velocities: [Double]

        public init() {
            offset = 0
            notes = [Note]()
            velocities = [Double]()
        }
    }

    public var filePath: String
    public var startOffset: Int
    public var data = RealArray()
    public var events = [Event]()
    public var features = [Feature]()

    public init() {
        self.filePath = ""
        self.startOffset = 0
    }

    public init(filePath: String, startOffset: Int) {
        self.filePath = filePath
        self.startOffset = startOffset
    }
}
