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
    public let peakHeights0: PeakHeightsFeatureGenerator
    public let peakHeights1: PeakHeightsFeatureGenerator
    public let peakHeightsFlux: FluxFeatureGenerator
    public let spectrumFeature0: SpectrumFeatureGenerator
    public let spectrumFeature1: SpectrumFeatureGenerator
    public let spectrumFluxFeature: FluxFeatureGenerator

    public init(windowSize: Int) {
        self.windowSize = windowSize
        stepSize = windowSize / Configuration.stepFraction
        baseFrequency = Configuration.samplingFrequency / Double(windowSize)

        windowingFunction = ValueArray<Double>(count: windowSize)
        withPointer(&windowingFunction) { pointer in
            vDSP_hamm_windowD(pointer, vDSP_Length(windowSize), 0)
        }

        fft = FFTDouble(inputLength: windowSize)
        peakExtractor = PeakExtractor()

        peakLocations = PeakLocationsFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        peakHeights0 = PeakHeightsFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        peakHeights1 = PeakHeightsFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        peakHeightsFlux = FluxFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        spectrumFeature0 = SpectrumFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        spectrumFeature1 = SpectrumFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
        spectrumFluxFeature = FluxFeatureGenerator(notes: Configuration.bandNotes, bandSize: Configuration.bandSize)
    }

    public func reset() {
        peakLocations.reset()
        peakHeights0.reset()
        peakHeights1.reset()
        peakHeightsFlux.reset()
        spectrumFeature0.reset()
        spectrumFeature1.reset()
        spectrumFluxFeature.reset()
    }

    public func generateFeatures<C: LinearType where C.Element == Double>(data0: C, _ data1: C) -> Feature {
        let rms = Double(rmsq(data1))
       
        // Previous spectrum
        let spectrum0 = spectrumValues(data0)

        // Previous heights
        let points0 = spectrumPoints(spectrum0)
        let peaks0 = peakExtractor.process(points0, rms: rms).sort{ $0.y > $1.y }

        // Extract peaks
        let spectrum1 = spectrumValues(data1)
        let points1 = spectrumPoints(spectrum1)
        let peaks1 = peakExtractor.process(points1, rms: rms).sort{ $0.y > $1.y }
        
        peakLocations.update(peaks1)
        peakHeights0.update(peaks0, rms: rms)
        peakHeights1.update(peaks1, rms: rms)
        peakHeightsFlux.update(data0: peakHeights0.data, data1: peakHeights1.data)
        spectrumFeature0.update(spectrum: spectrum0, baseFrequency: baseFrequency)
        spectrumFeature1.update(spectrum: spectrum1, baseFrequency: baseFrequency)
        spectrumFluxFeature.update(data0: spectrumFeature0.data, data1: spectrumFeature1.data)

        var feature = Feature()
        feature.rms = Float(rms)
        for i in 0..<Configuration.bandNotes.count {
            feature.spectrum[i] = Float(spectrumFeature1.data[i])
            feature.spectralFlux[i] = Float(spectrumFluxFeature.data[i])
            feature.peakHeights[i] = Float(peakHeights1.data[i])
            feature.peakHeightsFlux[i] = Float(peakHeightsFlux.data[i])
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
