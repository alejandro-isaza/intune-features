//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge

public class PeakExtractor {
    let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func process(spectrum: ValueArray<Double>, rms: Double) -> ValueArray<Double> {
        let peaks = findPeaks(spectrum)
        return choosePeaks(peaks)
    }

    func findPeaks(spectrum: ValueArray<Double>) -> ValueArray<Double> {
        let peaks = ValueArray<Double>(count: spectrum.count, repeatedValue: 0)
        
        for i in 1..<spectrum.count - 1 {
            let peak = spectrum[i]
            if spectrum[i-1] <= peak && peak >= spectrum[i+1] {
                peaks[i] = peak
            }
        }
        
        return peaks
    }

    func choosePeaks(peaks: ValueArray<Double>) -> ValueArray<Double> {
        var chosenPeaks = [(Int, Double)]()

        var currentPeakRange = 0...0
        for (band, peak) in peaks.enumerate() {
            if currentPeakRange.contains(band) {
                if let lastPeak = chosenPeaks.last where lastPeak.1 < peak {
                    chosenPeaks.removeLast()
                    chosenPeaks.append((band, peak))
                    currentPeakRange = binCutoffRange(band)
                }
            } else {
                chosenPeaks.append((band, peak))
                currentPeakRange = binCutoffRange(band)
            }
        }

        let newPeaks = ValueArray<Double>(count: peaks.count, repeatedValue: 0)
        for (band, peak) in chosenPeaks {
            newPeaks[band] = peak
        }
        return newPeaks
    }

    func binCutoffRange(band: Int) -> Range<Int> {
        let note = configuration.noteForBand(band)

        let upperBound = configuration.bandForNote(note + configuration.minimumPeakDistance)
        let lowerBound = configuration.bandForNote(note - configuration.minimumPeakDistance)

        return lowerBound...upperBound
    }

}
