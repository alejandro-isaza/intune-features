// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation

extension CollectionType where Index == Int {
    /// Return a copy of `self` with its elements shuffled
    func shuffle() -> [Generator.Element] {
        var list = Array(self)
        list.shuffleInPlace()
        return list
    }
}

extension MutableCollectionType where Index == Int {
    /// Shuffle the elements of `self` in-place.
    mutating func shuffleInPlace() {
        // empty and single-element collections don't shuffle
        if count < 2 { return }

        for i in 0..<count - 1 {
            let j = randomInRange(i..<count)
            guard i != j else { continue }
            swap(&self[i], &self[j])
        }
    }
}

public func randomInRange(range: Range<Int>) -> Int {
    assert(!range.isEmpty)

    let upperBound = UInt.max - UInt.max % UInt(range.count)
    var rnd = UInt(0)
    repeat {
        arc4random_buf(&rnd, sizeofValue(rnd))
    } while rnd >= upperBound

    return range.startIndex + Int(rnd % UInt(range.count))
}
