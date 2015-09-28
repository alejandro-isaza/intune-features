import AudioKit
import PlotKit
import Surge
import XCPlayground

//: Set parameters
let count = 2048
let fs = 44100.0
let fb = fs / Double(count)
let fft = FFT(inputLength: count)


//: This function generates the power spectral density of the first `count` samples of an audio file
func psd(name: String) -> [Point] {
    let filePath = NSBundle.mainBundle().pathForResource(name, ofType: "wav")!
    let audioFile = AudioFile(filePath: filePath)!
    assert(audioFile.sampleRate == fs)

    var data = [Double](count: count, repeatedValue: 0.0)
    audioFile.readFrames(&data, count: count)

    let psd = sqrt(fft.forwardMags(data))
    return (0..<psd.count).map{ Point(x: fb * Double($0), y: psd[$0]) }
}

//: Create a PlotView and show it
let plotView = PlotView(frame: NSRect(x: 0, y: 0, width: 1024, height: 400))
XCPShowView("PSD", view: plotView)

//: Generate a PointSet with the x and y values of the data
let pointSetC = PointSet(points: psd("72"))
plotView.addPointSet(pointSetC)

//: You can customize the plot intervals
plotView.fixedXInterval = Interval(min: 0.0, max: 10000)

//: You can also overlay mutiple data sets
let pointSetD = PointSet(points: psd("74"))
pointSetD.color = NSColor.blueColor()
plotView.addPointSet(pointSetD)

