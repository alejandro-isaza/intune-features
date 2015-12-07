//  Copyright © 2015 Venture Media. All rights reserved.

import Upsurge

public struct FeatureBuilder {
    /// Input audio data sampling frequency
    public static let samplingFrequency = 44100.0

    /// Analysis window size in samples
    public static let sampleCount = 8*1024

    /// Step size between analysis windows
    public static let sampleStep = 1024

    /// The range of notes to consider for labeling
    public static let notes = 36...96

    /// The range of notes to include in the spectrums
    public static let bandNotes = 24...120

    /// The note resolution for the spectrums
    public static let bandSize = 1.0
    
    /// The peak height cutoff as a multiplier of the RMS
    public static let peakHeightCutoffMultiplier = 0.05

    /// The minimum distance between peaks in notes
    public static let peakMinimumNoteDistance = 0.5

    // Helpers
    public var window: RealArray
    public let fft = FFT(inputLength: sampleCount)
    public let peakExtractor = PeakExtractor(heightCutoffMultiplier: peakHeightCutoffMultiplier, minimumNoteDistance: peakMinimumNoteDistance)
    public let fb = Double(samplingFrequency) / Double(sampleCount)
    
    // Features
    public let rms: RMSFeature = RMSFeature()
    public let peakLocations = PeakLocationsFeature(notes: bandNotes, bandSize: bandSize)
    public let peakHeights: PeakHeightsFeature = PeakHeightsFeature(notes: bandNotes, bandSize: bandSize)
    public let spectrumFeature0: SpectrumFeature = SpectrumFeature(notes: bandNotes, bandSize: bandSize)
    public let spectrumFeature1: SpectrumFeature = SpectrumFeature(notes: bandNotes, bandSize: bandSize)
    public let spectrumFluxFeature: SpectrumFluxFeature = SpectrumFluxFeature(notes: bandNotes, bandSize: bandSize)

    public init() {
        window = RealArray(count: FeatureBuilder.sampleCount)
        vDSP_hamm_windowD(window.mutablePointer, vDSP_Length(FeatureBuilder.sampleCount), 0)
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
        spectrumFeature0.update(spectrum: spectrum0, baseFrequency: fb)
        spectrumFeature1.update(spectrum: spectrum1, baseFrequency: fb)
        spectrumFluxFeature.update(spectrum0: spectrumFeature0.data, spectrum1: spectrumFeature1.data)
        
        return [
            "rms": rms.data.copy(),
            "peak_locations": peakLocations.data.copy(),
            "peak_heights": peakHeights.data.copy(),
            "spectrum": spectrumFeature1.data.copy(),
            "spectrum_flux": spectrumFluxFeature.data.copy()
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