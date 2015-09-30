import AudioKit
import PlotKit
import Surge
import XCPlayground

let count = 2048
let fs = 44100.0
let fb = fs / Double(count)
let fft = FFT(inputLength: count)

//: This function generates the power spectral density of the first `count` samples of an audio file
func psd(name: String, offset: Int = 0) -> [Double] {
    let filePath = "\(XCPSharedDataDirectoryPath)/AudioData/\(name).caf"
    let audioFile = AudioFile(filePath: filePath)!
    audioFile.currentFrame = offset
    assert(audioFile.sampleRate == fs)

    var data = [Double](count: count, repeatedValue: 0.0)
    audioFile.readFrames(&data, count: count)

    return sqrt(sqrt(fft.forwardMags(data)))
}

func plotPSD(name: String, offset: Int) {
    let plotView = PlotView(frame: NSRect(x: 0, y: 0, width: 1024, height: 400))
    XCPShowView("PSD", view: plotView)

    plotView.fixedXInterval = Interval(min: 0, max: 10000)
    let xaxis = Axis(orientation: .Horizontal, ticks: .Space(distance: 1000))
    plotView.addAxis(xaxis)

    let yaxis = Axis(orientation: .Vertical, ticks: .Space(distance: 0.01))
    plotView.addAxis(yaxis)

    let data = psd(name, offset: offset)
    let points = (1..<data.count).map{ Point(x: fb * Double($0), y: data[$0]) }
    plotView.addPointSet(PointSet(points: points))
}

func plotAutocorrelation(name: String, offset: Int) {
    let plotView = PlotView(frame: NSRect(x: 0, y: 0, width: 1024, height: 400))
    XCPShowView("Autocorrelation", view: plotView)

    let xaxis = Axis(orientation: .Horizontal, ticks: .Space(distance: 512))
    plotView.addAxis(xaxis)

    let yaxis = Axis(orientation: .Vertical, ticks: .Space(distance: 0.01))
    plotView.addAxis(yaxis)
    plotView.fixedXInterval = Interval(min: 1024-256, max: 1024+256)
    plotView.addPointSet(PointSet(values: autocorrelation(psd(name, offset: offset))))
}


plotPSD("Annotations/Audio/a_whole_new_world", offset: 0)
plotAutocorrelation("Annotations/Audio/a_whole_new_world", offset: 0)
