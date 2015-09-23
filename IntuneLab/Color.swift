//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

import Foundation
import UIKit

public class Color {
    init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        set(hue: hue, saturation: saturation, brightness: brightness)
    }

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        set(red: red, green: green, blue: blue)
    }

    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0

    var max: CGFloat {
        return Swift.max(red, green, blue)
    }
    var min: CGFloat {
        return Swift.min(red, green, blue)
    }
    var chroma: CGFloat {
        return max - min
    }

    var hue: CGFloat? {
        get {
            if chroma == 0 {
                return nil;
            }

            var h: CGFloat = 0
            if max == red {
                h = fmod((green - blue) / chroma, 6.0)
            } else if max == green {
                h = (blue - red) / chroma + 2
            } else if max == blue {
                h = (red - green) / chroma + 4
            }

            return 60.0 * h
        }
    }

    var brightness: CGFloat {
        get {
            return (max + min) / 2
        }
    }

    var saturation: CGFloat {
        get {
            let l = brightness
            if l == 0 || l == 1 {
                return 0
            }
            return chroma / (1 - abs(2*l - 1))
        }
    }

    func set(red red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func set(hue hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        red = 0
        green = 0
        blue = 0

        let chroma = (1 - abs(2*brightness - 1)) * saturation
        let h = hue / 60.0
        let x = chroma * (1 - abs(fmod(h, 2) - 1))
        if h < 1 {
            red = chroma
            green = x
        } else if h < 2 {
            red = x
            green = chroma
        } else if h < 3 {
            green = chroma
            blue = x
        } else if h < 4 {
            green = x
            blue = chroma
        } else if h < 5 {
            red = x
            blue = chroma
        } else if h < 6 {
            red = chroma
            blue = x
        }

        let min = brightness - 0.5 * chroma
        red += min
        blue += min
        green += min
    }

    var UIColor: UIKit.UIColor {
        return UIKit.UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
