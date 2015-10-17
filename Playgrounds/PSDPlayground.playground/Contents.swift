//: ## Setup
import Peak
import Upsurge
import XCPlayground

//: Define a function to plot values on the timeline
func plot<T: SequenceType>(values: T, title: String) {
    for value in values {
        XCPCaptureValue(title, value: value)
    }
}

//: ## Manually generating a wave
//: We generate a sine wave with a specific frequency. We make sure that the frequency is an integer multiple of the lowest frequency representable in the FFT so that we get a single peak with unit magnitude.
let count = 1024
let fs = 44100.0
let f0 = 10 * fs/Double(count)

let t = RealArray((0..<count).map{ Double($0) / fs })
let y = sin(t * 2.0 * M_PI * f0)
plot(y, title: "Wave")

//: Estimate the power spectral density (PSD) by doing a fast fourier trasnform. In this case the estimate is spot on because it's a clean sine wave.
let fft = FFT(inputLength: count)
let psd = fft.forwardMags(y)
plot(psd, title: "PSD")


//: ## Loading an audio file
//: Now let's try loading an audio file from disk of a piano key being played. We take the square root of the psd to make the peaks more pronounced.
let filePath = NSBundle.mainBundle().pathForResource("72", ofType: "wav")!
let audioFile = AudioFile(filePath: filePath)!

var data = [Double](count: count, repeatedValue: 0.0)
audioFile.readFrames(&data, count: count)
plot(data, title: "Piano Key")

let psd2 = fft.forwardMags(RealArray(data))
plot(sqrt(psd2), title: "Piano Key PSD")
