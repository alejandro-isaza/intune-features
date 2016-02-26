//  Copyright © 2016 Venture Media. All rights reserved.

import FeatureExtraction
import Upsurge

let windowSize = 2048
let stepSize = windowSize / Configuration.stepFraction

struct Example {
    var filePath = ""
    var frameOffset = 0
    var data = ValueArray<Double>()
}
