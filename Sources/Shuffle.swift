// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation

extension Collection where Index == Int {
    /// Return a copy of `self` with its elements shuffled
    func shuffle() -> [Iterator.Element] {
        var list = Array(self)
        list.shuffleInPlace()
        return list
    }
}

extension MutableCollection where Index == Int {
    /// Shuffle the elements of `self` in-place.
    mutating func shuffleInPlace() {
        // empty and single-element collections don't shuffle
        if count < 2 { return }

        for i in 0..<Int((count - 1).toIntMax()) {
            let j = randomInRange(i..<Int(count.toIntMax()))
            guard i != j else { continue }
            swap(&self[i], &self[j])
        }
    }
}

public func randomInRange(_ range: CountableRange<Int>) -> Int {
    assert(!range.isEmpty)

    let upperBound = UInt.max - UInt.max % UInt(range.count)
    var rnd = UInt(0)
    repeat {
        arc4random_buf(&rnd, MemoryLayout.size(ofValue: rnd))
    } while rnd >= upperBound

    return range.lowerBound + Int(rnd % UInt(range.count))
}
