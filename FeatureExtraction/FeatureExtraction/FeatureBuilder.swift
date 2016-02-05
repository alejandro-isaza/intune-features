//  Copyright © 2015 Venture Media. All rights reserved.

import Accelerate
import Upsurge

public struct FeatureBuilder {
    /// Input audio data sampling frequency
    public static let samplingFrequency = 44100.0

    /// Analysis window size in samples
    public static let windowSize = 8*1024

    /// Step size between analysis windows
    public static let stepSize = 1024

    /// The range of notes to consider for labeling
    public static let notes = 21...108

    /// The range of notes to include in the spectrums
    public static let bandNotes = 21...120

    /// The note resolution for the spectrums
    public static let bandSize = 1.0
    
    /// The peak height cutoff as a multiplier of the RMS
    public static let peakHeightCutoffMultiplier = 0.05

    /// The minimum distance between peaks in notes
    public static let peakMinimumNoteDistance = 0.5

    /// Calculate the number of windows that fit inside the given number of samples
    public static func windowCountInSamples(samples: Int) -> Int {
        if samples < windowSize {
            return 0
        }
        return 1 + (samples - windowSize) / stepSize
    }

    /// Calculate the number of samples in the given number of contiguous windows
    public static func sampleCountInWindows(windowCount: Int) -> Int {
        if windowCount < 1 {
            return 0
        }
        return (windowCount - 1) * stepSize + windowSize
    }

    // Helpers
    public var window: ValueArray<Double>
    public let fft = FFTDouble(inputLength: windowSize)
    public let peakExtractor = PeakExtractor(heightCutoffMultiplier: peakHeightCutoffMultiplier, minimumNoteDistance: peakMinimumNoteDistance)
    public let fb = samplingFrequency / Double(windowSize)
    
    // Generators
    public let peakLocations = PeakLocationsFeatureGenerator(notes: bandNotes, bandSize: bandSize)
    public let peakHeights: PeakHeightsFeatureGenerator = PeakHeightsFeatureGenerator(notes: bandNotes, bandSize: bandSize)
    public let spectrumFeature0: SpectrumFeatureGenerator = SpectrumFeatureGenerator(notes: bandNotes, bandSize: bandSize)
    public let spectrumFeature1: SpectrumFeatureGenerator = SpectrumFeatureGenerator(notes: bandNotes, bandSize: bandSize)
    public let spectrumFluxFeature: SpectrumFluxFeatureGenerator = SpectrumFluxFeatureGenerator(notes: bandNotes, bandSize: bandSize)

    public init() {
        window = ValueArray<Double>(count: FeatureBuilder.windowSize)
        withPointer(&window) { pointer in
            vDSP_hamm_windowD(pointer, vDSP_Length(FeatureBuilder.windowSize), 0)
        }
    }

    public func generateFeatures<C: LinearType where C.Element == Double>(data0: C, _ data1: C) -> Feature {
        let rms = Double(rmsq(data1))
        
        // Previous spectrum
        let spectrum0 = spectrumValues(data0)
        
        // Extract peaks
        let spectrum1 = spectrumValues(data1)
        let points1 = spectrumPoints(spectrum1)
        let peaks1 = peakExtractor.process(points1, rms: rms).sort{ $0.y > $1.y }
        
        peakLocations.update(peaks1)
        peakHeights.update(peaks1, rms: rms)
        spectrumFeature0.update(spectrum: spectrum0, baseFrequency: fb)
        spectrumFeature1.update(spectrum: spectrum1, baseFrequency: fb)
        spectrumFluxFeature.update(spectrum0: spectrumFeature0.data, spectrum1: spectrumFeature1.data)

        var feature = Feature()
        feature.rms = Float(rms)
        for i in 0..<FeatureBuilder.bandNotes.count {
            feature.spectrum[i] = Float(spectrumFeature1.data[i])
            feature.spectralFlux[i] = Float(spectrumFluxFeature.data[i])
            feature.peakHeights[i] = Float(peakHeights.data[i])
            feature.peakLocations[i] = Float(peakLocations.data[i])
        }
        return feature
    }
    
    /// Compute the power spectrum values
    public func spectrumValues<C: LinearType where C.Element == Double>(data: C) -> ValueArray<Double> {
        return sqrt(fft.forwardMags(data * window))
    }

    /// Convert from spectrum values to frequency, value points
    public func spectrumPoints<C: LinearType where C.Element == Double>(spectrum: C) -> [Point] {
        var points = [Point]()
        points.reserveCapacity(spectrum.count)
        for i in 0..<spectrum.count {
            let v = spectrum[i]
            points.append(Point(x: fb * Double(i), y: v))
        }
        return points
    }
}