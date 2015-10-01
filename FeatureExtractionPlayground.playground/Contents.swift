import AudioKit
import PlotKit
import Surge
import FeatureExtraction
import XCPlayground

//: Set parameters
let note = 72
let count = Int(floor(exp2(11.0)))
let fs = 44100.0
let fb = fs / Double(count)
let fft = FFT(inputLength: count)

public typealias Point = Surge.Point<Double>

//: This function generates the power spectral density of the first `count` samples of an audio file
func psd(name: String) -> [Point] {
    let filePath = "\(XCPSharedDataDirectoryPath)/AudioData/Notes/Arachno/\(name).caf"
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
let xaxis = Axis(orientation: .Horizontal, ticks: .Space(distance: 250))
plotView.addAxis(xaxis)

//: Add y axis with tics every 0.01
let yaxis = Axis(orientation: .Vertical, ticks: .Space(distance: 0.01))
plotView.addAxis(yaxis)

//: Generate a PointSet with the x and y values of the data
let fftData = psd(String(note))
let pointSetC = PointSet(points: fftData)
plotView.addPointSet(pointSetC)

//: Extract peaks
let peakLocations = process(pointSetC.points)
let points = (0..<peakLocations.count).map{ Point(x: peakLocations[$0].x, y: peakLocations[$0].y) }
let pointSetD = PointSet(points: points)
pointSetD.color = NSColor.blueColor()
pointSetD.lines = false
pointSetD.pointType = .Ring(radius: 4)
plotView.addPointSet(pointSetD)

//: You can customize the plot intervals
plotView.fixedXInterval = Interval(min: 0, max: 5000)

//: Here we create custom tick marks indicating each note
var ticks = [TickMark]()
for var n = 24; n <= 108; n += 1 {
    ticks.append(TickMark(noteToFreq(Double(n)), label: n % 6 == 0 ? String(n) : ""))
}
var topaxis = Axis(orientation: .Horizontal, ticks: .List(ticks: ticks))
topaxis.position = .End
plotView.addAxis(topaxis)

//: Here we plot where we expect the fft peak to be
let pointSetExpected = PointSet(points: (1..<10).map{ Point(x: noteToFreq(Double(note)) * Double($0), y: 0.05) })
pointSetExpected.pointType = .Ring(radius: 1)
pointSetExpected.lines = false
pointSetExpected.color = NSColor.blackColor()
plotView.addPointSet(pointSetExpected)

