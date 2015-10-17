import Peak
import PlotKit
import Upsurge
import XCPlayground

let plotSize = CGSize(width: 1024, height: 400)
let count = 2048
let fs = 44100.0
let time = Double(count) / fs

//: Read audio data from a file starting at the given offset
func readAudio(name: String, offset: Int = 0) -> [Double] {
    let filePath = "\(XCPSharedDataDirectoryPath)/AudioData/\(name).caf"
    let audioFile = AudioFile(filePath: filePath)!
    audioFile.currentFrame = offset
    assert(audioFile.sampleRate == fs)

    var data = [Double](count: count, repeatedValue: 0.0)
    audioFile.readFrames(&data, count: count)

    return data
}

func plotAudio(data: [Double]) {
    let plotView = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
    plotView.addAxis(Axis(orientation: .Horizontal, ticks: .Space(distance: 0.005)))
    plotView.addAxis(Axis(orientation: .Vertical, ticks: .Space(distance: 0.1)))
    XCPShowView("Audio", view: plotView)

    let points = (1..<data.count).map{ Point(x: Double($0) / fs, y: data[$0]) }
    plotView.addPointSet(PointSet(points: points))
}

func plotAutocorrelation(data: [Double]) {
    let data = autocorrelation(data)
    guard let height = data.maxElement({ abs($0) < abs($1) }) else {
        return
    }

    let plotView = PlotView(frame: NSRect(origin: CGPointZero, size: plotSize))
    plotView.fixedXInterval = Interval(min: -time, max: time)
    plotView.addAxis(Axis(orientation: .Horizontal, ticks: .Fit(count: 10)))
    plotView.fixedYInterval = Interval(min: -height, max: height)
    plotView.addAxis(Axis(orientation: .Vertical, ticks: .Space(distance: 10)))
    XCPShowView("Autocorrelation", view: plotView)

    let points = (0..<data.count).map{ Point(x: (Double($0) - Double(data.count)/2) / fs, y: data[$0]) }
    plotView.addPointSet(PointSet(points: points))
}

let monophonic = "Notes/AcousticGrandPiano_YDP/72"
let polyphonic = "Annotations/Audio/a_whole_new_world"
let data = readAudio(monophonic, offset: 0)

plotAudio(data)
plotAutocorrelation(data)
