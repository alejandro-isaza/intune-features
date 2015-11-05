//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public struct FeatureBuilder {
    // Basic parameters
    public static let sampleRate = 44100
    public static let sampleCount = 4*1024
    public static let sampleStep = sampleCount / 2
    public static let labelFunction: [Int] -> [Int] = { $0 }
    
    // Notes and bands parameters
    public static let notes = 36...96
    public static let bandNotes = 24...120
    public static let bandSize = 1.0
    
    // Peaks parameters
    public static let peakHeightCutoffMultiplier = 0.05
    public static let peakMinimumNoteDistance = 0.5

    // Helpers
    public var window: RealArray
    public let fft = FFT(inputLength: sampleCount)
    public let peakExtractor = PeakExtractor(heightCutoffMultiplier: peakHeightCutoffMultiplier, minimumNoteDistance: peakMinimumNoteDistance)
    public let fb = Double(sampleRate) / Double(sampleCount)
    
    // Features
    public let rms: RMSFeature = RMSFeature()
    public let peakLocations = PeakLocationsFeature(notes: bandNotes, bandSize: bandSize)
    public let peakHeights: PeakHeightsFeature = PeakHeightsFeature(notes: bandNotes, bandSize: bandSize)
    public let bands0: SpectrumFeature = SpectrumFeature(notes: bandNotes, bandSize: bandSize)
    public let bands1: SpectrumFeature = SpectrumFeature(notes: bandNotes, bandSize: bandSize)
    public let bandFluxes: BandFluxsFeature = BandFluxsFeature(notes: bandNotes, bandSize: bandSize)

    public init() {
        window = RealArray(count: FeatureBuilder.sampleCount)
        vDSP_hamm_windowD(window.mutablePointer, vDSP_Length(FeatureBuilder.sampleCount), 0)
    }

    public static func labelForNote(note: Int) -> [Int] {
        var label = [Int](count: notes.count, repeatedValue: 0)
        if notes.contains(note) {
            label[note - notes.startIndex] = 1
        }
        return label
    }

    public func generateFeatures(example: Example) -> [String: RealArray] {
        rms.update(example.data.1)
        
        // Previous spectrum
        let spectrum0 = spectrumValues(example.data.0)
        
        // Extract peaks
        let spectrum1 = spectrumValues(example.data.1)
        let points1 = spectrumPoints(spectrum1)
        let peaks1 = peakExtractor.process(points1, rms: rms.rms).sort{ $0.y > $1.y }
        
        peakLocations.update(peaks1)
        peakHeights.update(peaks1, rms: rms.rms)
        bands0.update(spectrum: spectrum0, baseFrequency: fb)
        bands1.update(spectrum: spectrum1, baseFrequency: fb)
        bandFluxes.update(bands0: bands0.data, bands1: bands1.data)
        
        return [
            "rms": rms.data.copy(),
            "peak_locations": peakLocations.data.copy(),
            "peak_heights": peakHeights.data.copy(),
            "bands": bands1.data.copy(),
            "band_fluxes": bandFluxes.data.copy()
        ]
    }
    
    /// Compute the power spectrum values
    public func spectrumValues(data: RealArray) -> RealArray {
        return sqrt(fft.forwardMags(data * window))
    }
    
    /// Convert from spectrum values to frequency, value points
    public func spectrumPoints(spectrum: RealArray) -> [Point] {
        var points = [Point]()
        points.reserveCapacity(spectrum.count)
        for i in 0..<spectrum.count {
            let v = spectrum[i]
            points.append(Point(x: fb * Real(i), y: v))
        }
        return points
    }
}