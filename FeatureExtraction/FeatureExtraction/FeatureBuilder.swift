//  Copyright © 2015 Venture Media. All rights reserved.

import Accelerate
import Upsurge

public struct FeatureBuilder {
    public let configuration: Configuration

    // Helpers
    public var windowingFunction: ValueArray<Double>
    public let fft: FFTDouble
    public let peakExtractor: PeakExtractor

    // Generators
    public let peakLocations: PeakLocationsFeatureGenerator
    public let peakHeights0: PeakHeightsFeatureGenerator
    public let peakHeights1: PeakHeightsFeatureGenerator
    public let peakFlux: FluxFeatureGenerator
    public let spectrumFeature0: SpectrumFeatureGenerator
    public let spectrumFeature1: SpectrumFeatureGenerator
    public let spectrumFluxFeature: FluxFeatureGenerator

    public init(configuration: Configuration) {
        self.configuration = configuration

        windowingFunction = ValueArray<Double>(count: configuration.windowSize)
        withPointer(&windowingFunction) { pointer in
            vDSP_hamm_windowD(pointer, vDSP_Length(configuration.windowSize), 0)
        }

        fft = FFTDouble(inputLength: configuration.windowSize)
        peakExtractor = PeakExtractor(configuration: configuration)

        spectrumFeature0 = SpectrumFeatureGenerator(configuration: configuration)
        spectrumFeature1 = SpectrumFeatureGenerator(configuration: configuration)
        spectrumFluxFeature = FluxFeatureGenerator(configuration: configuration)

        peakHeights0 = PeakHeightsFeatureGenerator(configuration: configuration)
        peakHeights1 = PeakHeightsFeatureGenerator(configuration: configuration)
        peakLocations = PeakLocationsFeatureGenerator(configuration: configuration)
        peakFlux = FluxFeatureGenerator(configuration: configuration)
    }

    public func reset() {
        spectrumFeature0.reset()
        spectrumFeature1.reset()
        spectrumFluxFeature.reset()

        peakHeights0.reset()
        peakHeights1.reset()
        peakLocations.reset()
        peakFlux.reset()
    }

    public func generateFeatures<C: LinearType where C.Element == Double>(data0: C, _ data1: C) -> Feature {
        let rms0 = Double(rmsq(data0))
        let rms1 = Double(rmsq(data1))
       
        // Compute spectrum
        let spectrum0 = spectrumValues(data0)
        let points0 = spectrumPoints(spectrum0)
        spectrumFeature0.update(spectrum: spectrum0, baseFrequency: configuration.baseFrequency)
        
        let spectrum1 = spectrumValues(data1)
        let points1 = spectrumPoints(spectrum1)
        spectrumFeature1.update(spectrum: spectrum1, baseFrequency: configuration.baseFrequency)

        spectrumFluxFeature.update(data0: spectrumFeature0.data, data1: spectrumFeature1.data)

        // Extract peaks
        let peaks0 = peakExtractor.process(points0, rms: rms0)
        let peaks1 = peakExtractor.process(points1, rms: rms1)

        peakHeights0.update(peaks0, rms: rms0)
        peakHeights1.update(peaks1, rms: rms1)
        peakLocations.update(peaks1)
        peakFlux.update(data0: peakHeights0.data, data1: peakHeights1.data)

        let feature = Feature(bandCount: configuration.bandCount)
        for i in 0..<configuration.bandCount {
            feature.spectrum[i] = Float(spectrumFeature1.data[i])
            feature.spectralFlux[i] = Float(spectrumFluxFeature.data[i])
            feature.peakHeights[i] = Float(peakHeights1.data[i])
            feature.peakLocations[i] = Float(peakLocations.data[i])
            feature.peakFlux[i] = Float(peakFlux.data[i])
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
            points.append(Point(x: configuration.baseFrequency * Double(i), y: v))
        }
        return points
    }
}
