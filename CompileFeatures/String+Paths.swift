// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation

extension String {
    mutating func appendPathComponent(_ component: String) {
        let strippedComponent: String
        if let first = component.characters.first , first == "/" {
            strippedComponent = component.substring(from: component.characters.index(component.startIndex, offsetBy: 1))
        } else {
            strippedComponent = component
        }
        
        if let last = self.characters.last , last == "/" {
            self += strippedComponent
        } else {
            self += "/" + strippedComponent
        }
    }

    var lastPathComponent: String {
        return (self as NSString).lastPathComponent
    }

    func stringByDeletingLastPathComponent(_ newExtension: String) -> String {
        return (self as NSString).deletingLastPathComponent
    }

    func stringByReplacingExtensionWith(_ newExtension: String) -> String {
        let noExtension: NSString = (self as NSString).deletingPathExtension as NSString
        return noExtension.appendingPathExtension(newExtension)!
    }

    func stringByAppendingPathComponent(_ component: String) -> String {
        return (self as NSString).appendingPathComponent(component)
    }

}

func buildPathFromParts(_ parts: [String]) -> String {
    guard var path = parts.first else {
        return ""
    }
    
    for part in parts[1..<parts.count] {
        path.appendPathComponent(part)
    }
    return path
}
