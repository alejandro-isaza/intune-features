//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakExtractor {
    let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func process(input: [Point], rms: Double) -> [Point] {
        let peaks = findPeaks(input)
        return choosePeaks(peaks)
    }

    func findPeaks(input: [Point]) -> [Point] {
        var peaks = [Point]()
        
        for i in 1...input.count-2 {
            let peak = input[i]
            if input[i-1].y <= peak.y && peak.y >= input[i+1].y {
                peaks.append(peak)
            }
        }
        
        return peaks
    }

    func choosePeaks(input: [Point]) -> [Point] {
        var chosenPeaks = [Point]()

        var currentPeakRange = 0.0...0.0
        for peak in input {
            if currentPeakRange.contains(peak.x) {
                if let lastPeak = chosenPeaks.last where lastPeak.y < peak.y {
                    chosenPeaks.removeLast()
                    chosenPeaks.append(peak)
                    currentPeakRange = binCutoffRange(peak.x)
                }
            } else {
                chosenPeaks.append(peak)
                currentPeakRange = binCutoffRange(peak.x)
            }
        }

        return chosenPeaks
    }

    func binCutoffRange(freq: Double) -> ClosedInterval<Double> {
        let note = freqToNote(freq)

        let upperBound = noteToFreq(note + configuration.minimumPeakDistance)
        let lowerBound = noteToFreq(note - configuration.minimumPeakDistance)

        return lowerBound...upperBound
    }

}
