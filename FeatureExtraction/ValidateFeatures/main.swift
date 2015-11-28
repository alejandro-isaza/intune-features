//  Copyright © 2015 Venture Media. All rights reserved.

import CommandLine
import Foundation

let cli = CommandLine(arguments: Process.arguments)

let filePath = StringOption(longFlag: "file", required: true, helpMessage: "Path to the HDF5 file.")
let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints a help message.")
cli.addOptions(filePath, help)

do {
    try cli.parse()
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}

if help.value {
    cli.printUsage()
    exit(EX_OK)
}

let trainValidateFeatures = ValidateFeatures(filePath: filePath.value!)
let passed = trainValidateFeatures.validate()
if passed {
    print("Validation passed")
    exit(EX_OK)
} else {
    print("Validation failed")
    exit(EX_DATAERR)
}
