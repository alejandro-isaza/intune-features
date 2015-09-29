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

//: Add x axis with one tick every 100Hz
let xaxis = Axis(orientation: .Horizontal, ticks: .Space(distance: 1000))
plotView.addAxis(xaxis)

//: Add y axis with tics every 0.01
let yaxis = Axis(orientation: .Vertical, ticks: .Space(distance: 0.01))
plotView.addAxis(yaxis)

//: Generate a PointSet with the x and y values of the data
let pointSetC = PointSet(points: psd("72"))
plotView.addPointSet(pointSetC)

//: You can customize the plot intervals
plotView.fixedXInterval = Interval(min: 0.0, max: 5000)

//: You can also overlay mutiple data sets
let pointSetD = PointSet(points: psd("74"))
pointSetD.color = NSColor.blueColor()
plotView.addPointSet(pointSetD)


//: Here we create custom tick marks indicating every octave
func noteToF(note: Double) -> Double {
    return 440.0 * exp2((note - 69.0) / 12.0)
}
var ticks = [TickMark]()
for var n = 24; n <= 108; n += 12 {
    ticks.append(TickMark(noteToF(Double(n)), label: "C\(n / 12 - 1)"))
}
var topaxis = Axis(orientation: .Horizontal, ticks: .List(ticks: ticks))
topaxis.position = .End
plotView.addAxis(topaxis)
