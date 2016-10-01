// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Accelerate
import Upsurge

open class FeatureBuilder {
    open let configuration: Configuration

    // Helpers
    open var windowingFunction: ValueArray<Double>
    open var spectrum0: ValueArray<Double>
    open var spectrum1: ValueArray<Double>
    open var points0: [Point]
    open var points1: [Point]
    open let fft: FFTDouble
    open let peakExtractor: PeakExtractor

    // Generators
    open let peakLocations: PeakLocationsFeatureGenerator
    open let peakHeights0: PeakHeightsFeatureGenerator
    open let peakHeights1: PeakHeightsFeatureGenerator
    open let peakFlux: FluxFeatureGenerator
    open let spectrumFeature0: SpectrumFeatureGenerator
    open let spectrumFeature1: SpectrumFeatureGenerator
    open let spectrumFluxFeature: FluxFeatureGenerator

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration

        windowingFunction = ValueArray<Double>(count: configuration.windowSize)
        withPointer(&windowingFunction) { pointer in
            vDSP_hamm_windowD(pointer, vDSP_Length(configuration.windowSize), 0)
        }

        fft = FFTDouble(inputLength: configuration.windowSize)
        peakExtractor = PeakExtractor(configuration: configuration)

        spectrum0 = ValueArray<Double>(count: configuration.windowSize / 2)
        spectrum1 = ValueArray<Double>(count: configuration.windowSize / 2)
        points0 = [Point]()
        points0.reserveCapacity(configuration.windowSize / 2)
        points1 = [Point]()
        points1.reserveCapacity(configuration.windowSize / 2)

        spectrumFeature0 = SpectrumFeatureGenerator(configuration: configuration)
        spectrumFeature1 = SpectrumFeatureGenerator(configuration: configuration)
        spectrumFluxFeature = FluxFeatureGenerator(configuration: configuration)

        peakHeights0 = PeakHeightsFeatureGenerator(configuration: configuration)
        peakHeights1 = PeakHeightsFeatureGenerator(configuration: configuration)
        peakLocations = PeakLocationsFeatureGenerator(configuration: configuration)
        peakFlux = FluxFeatureGenerator(configuration: configuration)
    }

    open func reset() {
        spectrumFeature0.reset()
        spectrumFeature1.reset()
        spectrumFluxFeature.reset()

        peakHeights0.reset()
        peakHeights1.reset()
        peakLocations.reset()
        peakFlux.reset()
    }

    open func generateFeatures<C: LinearType>(_ data0: C, _ data1: C, feature: inout Feature) where C.Element == Double {
        let rms0 = Double(rmsq(data0))
        let rms1 = Double(rmsq(data1))
       
        // Compute spectrum
        spectrumValues(data0, results: &spectrum0)
        spectrumPoints(spectrum0, points: &points0)
        spectrumFeature0.update(spectrum: spectrum0, baseFrequency: configuration.baseFrequency)
        
        spectrumValues(data1, results: &spectrum1)
        spectrumPoints(spectrum1, points: &points1)
        spectrumFeature1.update(spectrum: spectrum1, baseFrequency: configuration.baseFrequency)

        spectrumFluxFeature.update(data0: spectrumFeature0.data, data1: spectrumFeature1.data)

        // Extract peaks
        let peaks0 = peakExtractor.process(points0, rms: rms0)
        let peaks1 = peakExtractor.process(points1, rms: rms1)

        peakHeights0.update(peaks0, rms: rms0)
        peakHeights1.update(peaks1, rms: rms1)
        peakLocations.update(peaks1)
        peakFlux.update(data0: peakHeights0.data, data1: peakHeights1.data)

        for i in 0..<configuration.bandCount {
            feature.spectrum[i] = Float(spectrumFeature1.data[i])
            feature.spectralFlux[i] = Float(spectrumFluxFeature.data[i])
            feature.peakHeights[i] = Float(peakHeights1.data[i])
            feature.peakLocations[i] = Float(peakLocations.data[i])
            feature.peakFlux[i] = Float(peakFlux.data[i])
        }
    }
    
    /// Compute the power spectrum values
    open func spectrumValues<Input: LinearType>(_ data: Input, results: inout ValueArray<Double>) where Input.Element == Double {
        fft.forwardMags(data * windowingFunction, results: &results)
        sqrt(results, results: &results)
    }

    /// Convert from spectrum values to frequency, value points
    open func spectrumPoints<C: LinearType>(_ spectrum: C, points: inout [Point]) where C.Element == Double {
        points.reserveCapacity(spectrum.count)
        for i in 0..<spectrum.count {
            let v = spectrum[i]
            if i >= points.count {
                points.append(Point(x: 0, y: 0))
            }
            points[i] = Point(x: configuration.baseFrequency * Double(i), y: v)
        }
    }
}
