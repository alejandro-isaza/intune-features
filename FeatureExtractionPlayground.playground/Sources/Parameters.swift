import Foundation

public let plotSize = NSSize(width: 1024, height: 400)
public let notes = 36...96


public func testingFeatuesPath() -> String {
    guard let path = NSBundle.mainBundle().pathForResource("testing", ofType: "h5") else {
        fatalError("File not found")
    }
    return path
}

public func trainingFeaturesPath() -> String {
    guard let path = NSBundle.mainBundle().pathForResource("training", ofType: "h5") else {
        fatalError("File not found")
    }
    return path
}

public func delay(time: NSTimeInterval) {
    NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: time))
}

public func labelToNote(label: Double) -> Int? {
    guard label != 0 else {
        return nil
    }
    return Int(label) + notes.startIndex - 1
}
