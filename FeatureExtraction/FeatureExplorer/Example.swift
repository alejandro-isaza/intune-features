//  Copyright © 2016 Venture Media. All rights reserved.

import FeatureExtraction
import Upsurge

struct Example {
    var filePath = ""
    var frameOffset = 0
    var data: ValueArray<Double>

    init(dataSize: Int) {
        data = ValueArray<Double>(count: dataSize, repeatedValue: 0)
    }
}
