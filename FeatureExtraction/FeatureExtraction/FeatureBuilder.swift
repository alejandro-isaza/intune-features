//  Copyright © 2015 Venture Media. All rights reserved.

import Accelerate
import Upsurge

public struct FeatureBuilder {
    public let windowSize: Int
    public let stepSize: Int
    public let baseFrequency: Double

    // Helpers
    public var windowingFunction: ValueArray<Double>
    public let fft: FFTDouble
    public let peakExtractor: PeakExtractor

    // Generators
    public let peakLocations: PeakLocationsFeatureGenerator
    public let peakHeights: PeakHeightsFeatureGenerator
    public let spectrumFeature0: SpectrumFeatureGenerator
    public let spectrumFeature1: SpectrumFeatureGenerator
    public let spectrumFluxFeature: SpectrumFluxFeatureGenerator

    public init(windowSize: Int) {
        self.windowSize = windowSize
        stepSize = windowSize / Configuration.stepFraction
        baseFrequency = Configuration.samplingFrequency / Double(windowSize)

        windowingFunction = ValueArray<Double>(count: windowSize)
        withPointer(&windowingFunction) { pointer in
            vDSP_hamm_windowD(pointer, vDSP_Length(windowSize), 0)
        }

        fft = FFTDouble(inputLength: windowSize)
        peakExtractor = PeakExtractor(heightCutoffMultiplier: Configuration.peakHeightCutoffMultiplier, minimumNoteDistance: Configuration.peakMinimumNoteDistance)

        peakLocations = PeakLocationsFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        peakHeights = PeakHeightsFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        spectrumFeature0 = SpectrumFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        spectrumFeature1 = SpectrumFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        spectrumFluxFeature = SpectrumFluxFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
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
        spectrumFeature0.update(spectrum: spectrum0, baseFrequency: baseFrequency)
        spectrumFeature1.update(spectrum: spectrum1, baseFrequency: baseFrequency)
        spectrumFluxFeature.update(spectrum0: spectrumFeature0.data, spectrum1: spectrumFeature1.data)

        var feature = Feature()
        feature.rms = Float(rms)
        for i in 0..<Configuration.bandNotes.count {
            feature.spectrum[i] = Float(spectrumFeature1.data[i])
            feature.spectralFlux[i] = Float(spectrumFluxFeature.data[i])
            feature.peakHeights[i] = Float(peakHeights.data[i])
            feature.peakLocations[i] = Float(peakLocations.data[i])
        }
        return feature
    }
    
    /// Compute the power spectrum values
    public func spectrumValues<C: LinearType where C.Element == Double>(data: C) -> ValueArray<Double> {
        return sqrt(fft.forwardMags(data * windowingFunction))
    }

    /// Convert from spectrum values to frequency, value points
    public func spectrumPoints<C: LinearType where C.Element == Double>(spectrum: C) -> [Point] {
        var points = [Point]()
        points.reserveCapacity(spectrum.count)
        for i in 0..<spectrum.count {
            let v = spectrum[i]
            points.append(Point(x: baseFrequency * Double(i), y: v))
        }
        return points
    }
}
