//  Copyright © 2015 Venture Media Labs. All rights reserved.

import Foundation
import AudioToolbox

extension MusicTrack : SequenceType {
    public typealias Generator = MusicTrackGenerator
    
    public func generate() -> MusicTrackGenerator {
        return MusicTrackGenerator(track: self)
    }
}

public class MusicTrackGenerator : GeneratorType {
    public typealias Element = MIDIEvent
    
    var it = MusicEventIterator()
    
    init(track: MusicTrack) {
        guard NewMusicEventIterator(track, &it) == noErr else {
            fatalError("Failed to create an music event iterator")
        }
    }
    
    var hasEvent: Bool {
        var hasEvent = DarwinBoolean(false)
        guard MusicEventIteratorHasCurrentEvent(it, &hasEvent) == noErr else {
            return false
        }
        return Bool(hasEvent)
    }
    
    public func next() -> MIDIEvent? {
        guard hasEvent else {
            return nil
        }
        
        var event = MIDIEvent()
        guard MusicEventIteratorGetEventInfo(it, &event.timeStamp, &event.type, &event.data, &event.dataSize) == noErr else {
            return nil
        }
        
        MusicEventIteratorNextEvent(it)
        return event
    }
}