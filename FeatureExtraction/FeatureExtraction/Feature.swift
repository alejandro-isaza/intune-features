//  Copyright © 2016 Venture Media. All rights reserved.

import Upsurge

public struct Feature {
    public var spectrum: ValueArray<Float>
    public var spectralFlux: ValueArray<Float>
    public var peakHeights: ValueArray<Float>
    public var peakFlux: ValueArray<Float>
    public var peakLocations: ValueArray<Float>

    public init(bandCount: Int) {
        spectrum = ValueArray<Float>(count: bandCount)
        spectralFlux = ValueArray<Float>(count: bandCount)
        peakHeights = ValueArray<Float>(count: bandCount)
        peakFlux = ValueArray<Float>(count: bandCount)
        peakLocations = ValueArray<Float>(count: bandCount)
    }

    public init(rms: Float, spectrum: ValueArray<Float>, spectralFlux: ValueArray<Float>, peakHeights: ValueArray<Float>, peakHeightsFlux: ValueArray<Float>, peakLocations: ValueArray<Float>) {
        self.spectrum = spectrum
        self.spectralFlux = spectralFlux
        self.peakHeights = peakHeights
        self.peakFlux = peakHeightsFlux
        self.peakLocations = peakLocations
    }
}
