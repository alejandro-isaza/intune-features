//  Copyright © 2016 Venture Media. All rights reserved.

import FeatureExtraction
import Cocoa

extension Note {
    var color: NSColor {
        return NSColor(
            hue: CGFloat(colorNumber) / 7,
            saturation: isSharp ? 0.5 : 1,
            brightness: 1 - abs(CGFloat(octave) - 4) / 6,
            alpha: 1)
    }

    var colorNumber: Int {
        switch note {
        case .C: return 0
        case .D: return 1
        case .E: return 2
        case .F: return 3
        case .G: return 4
        case .A: return 5
        case .B: return 6
        case .CSharp: return 0
        case .DSharp: return 1
        case .FSharp: return 3
        case .GSharp: return 4
        case .ASharp: return 5
        }
    }
}
