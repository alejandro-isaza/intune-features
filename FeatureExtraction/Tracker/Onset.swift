//  Copyright © 2016 Venture Media. All rights reserved.

import FeatureExtraction

public struct Onset {
    var notes: [Note]
    var start: Int

    /// The time of this event in seconds when played at the song's tempo
    var wallTime: Double
}
