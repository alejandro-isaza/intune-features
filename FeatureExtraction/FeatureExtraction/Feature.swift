//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

public protocol Feature {
    /// Return the size of one feature when serialized
    static func size() -> Int

    /// Serialize the feature
    func serialize() -> [Double]
}
