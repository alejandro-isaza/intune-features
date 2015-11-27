//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation


let trainingHDF5File = "training.h5"
let testingHDF5File = "testing.h5"

let trainValidateFeatures = ValidateFeatures(filePath: trainingHDF5File)
print("Training File:  \(trainValidateFeatures.validate())")
let testValidateFeatures = ValidateFeatures(filePath: testingHDF5File)
print("Testing File:  \(testValidateFeatures.validate())")

