//  Copyright © 2016 Venture Media. All rights reserved.

import Upsurge

public struct Feature {
    public var rms: Float
    public var spectrum: ValueArray<Float>
    public var spectralFlux: ValueArray<Float>
    public var peakHeights: ValueArray<Float>
    public var peakHeightsFlux: ValueArray<Float>
    public var peakLocations: ValueArray<Float>

    public init() {
        rms = 0
        spectrum = ValueArray<Float>(count: Configuration.bandNotes.count)
        spectralFlux = ValueArray<Float>(count: Configuration.bandNotes.count)
        peakHeights = ValueArray<Float>(count: Configuration.bandNotes.count)
        peakHeightsFlux = ValueArray<Float>(count: Configuration.bandNotes.count)
        peakLocations = ValueArray<Float>(count: Configuration.bandNotes.count)
    }

    public init(rms: Float, spectrum: ValueArray<Float>, spectralFlux: ValueArray<Float>, peakHeights: ValueArray<Float>, peakHeightsFlux: ValueArray<Float>, peakLocations: ValueArray<Float>) {
        self.rms = rms
        self.spectrum = spectrum
        self.spectralFlux = spectralFlux
        self.peakHeights = peakHeights
        self.peakHeightsFlux = peakHeightsFlux
        self.peakLocations = peakLocations
    }
}
