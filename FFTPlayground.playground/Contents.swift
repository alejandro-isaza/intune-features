import Surge
import XCPlayground

//: Define a function to plot values on the timeline
func plot<T>(values: [T], title: String) {
    for value in values {
        XCPCaptureValue(title, value: value)
    }
}

//: Define the parameters of the waveform
let fs = 44100.0
let f0 = 10*43.06640625
let count = 512

let values = [Double](count: 10, repeatedValue: 10)

//: Generate a sine wave
let t = (0..<count).map{ Double($0) / fs }
let y = sin(t * 2.0 * M_PI * f0)
plot(y, title: "Wave")

//: Generate the power spectral density (PSD)
let fft = FFT(inputLength: count)
let psd = fft.forwardMags(y)
plot(psd, title: "PSD")
