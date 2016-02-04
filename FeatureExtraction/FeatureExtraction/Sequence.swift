//  Copyright © 2016 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public class Sequence {
    public static let minimumSequenceSamples = 2 * FeatureBuilder.windowSize
    public static let minimumSequenceDuration = Double(minimumSequenceSamples) / FeatureBuilder.samplingFrequency
    public static let maximumSequenceDuration = 1.0
    public static let maximumSequenceSamples = Int(maximumSequenceDuration * FeatureBuilder.samplingFrequency)

    public class Event {
        public var offset: Int
        public var notes: [Note]
        public var velocities: [Float]

        public init() {
            offset = 0
            notes = [Note]()
            velocities = [Float]()
        }
    }

    public var filePath: String
    public var startOffset: Int
    public var data = ValueArray<Double>()
    public var events = [Event]()
    public var features = [Feature]()
    public var featureOnsetValues = [Float]()
    public var featurePolyphonyValues = [Float]()

    public init() {
        self.filePath = ""
        self.startOffset = 0
    }

    public init(filePath: String, startOffset: Int) {
        self.filePath = filePath
        self.startOffset = startOffset
    }
}
