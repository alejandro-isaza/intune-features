//  Copyright © 2015 Venture Media Labs. All rights reserved.

import Foundation
import AudioToolbox

public struct MIDIEvent {
    var timeStamp = MusicTimeStamp()
    var type = MusicEventType()
    var data = UnsafePointer<Void>()
    var dataSize = UInt32()
}
