//  Copyright © 2015 Venture Media. All rights reserved.

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
            let j = random(count - i) + i
            guard i != j else { continue }
            swap(&self[i], &self[j])
        }
    }
}

public func random(upper_bound: Int) -> Int {
    let range = Int.max - Int.max % upper_bound
    var rnd = 0
    repeat {
        arc4random_buf(&rnd, sizeofValue(rnd))
    } while rnd >= range

    return rnd % upper_bound
}
