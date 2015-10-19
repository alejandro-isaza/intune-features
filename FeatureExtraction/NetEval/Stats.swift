//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

struct Stats {
    let exampleCount: Int
    var matches = 0
    var totalMatchValue = 0.0
    var totalMismatchValue = 0.0
    var matchesByLabel = [Int: (Int, Int)]()

    var accuracy: Double {
        return Double(matches) / Double(exampleCount)
    }
    
    init(exampleCount: Int) {
        self.exampleCount = exampleCount
    }

    mutating func addMatch(label label: Int, value: Double) {
        matches += 1
        totalMatchValue += value
        if var tuple = matchesByLabel[label] {
            tuple.0 += 1
            tuple.1 += 1
            matchesByLabel.updateValue(tuple, forKey: label)
        } else {
            matchesByLabel[label] = (1, 1)
        }

    }

    mutating func addMismatch(expectedLabel expectedLabel: Int, actualLabel: Int, value: Double) {
        totalMismatchValue += value
        if var tuple = matchesByLabel[expectedLabel] {
            tuple.1 += 1
            matchesByLabel.updateValue(tuple, forKey: expectedLabel)
        } else {
            matchesByLabel[expectedLabel] = (0, 1)
        }
    }

    func print() {
        Swift.print("Average match value \(totalMatchValue/Double(matches))")
        Swift.print("Average mismatch value \(totalMismatchValue/Double(exampleCount-matches))")
        for label in matchesByLabel.keys.sort() {
            let (matches, total) = matchesByLabel[label]!
            Swift.print("\(label): \(matches) / \(total) = \(Double(matches)/Double(total))")
        }
    }
}
