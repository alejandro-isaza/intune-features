// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import IntuneFeatures

protocol Builder {
    /// Calls the closure for every window in a file
    func forEachWindow(@noescape action: (Window) throws -> ()) rethrows

    /// The list of events compiled from all windows in a file
    var events: [Event] { get }
}
