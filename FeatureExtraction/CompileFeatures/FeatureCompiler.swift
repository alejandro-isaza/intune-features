//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation

import Peak
import FeatureExtraction
import HDF5Kit
import Upsurge

func midiNoteLabel(notes: Range<Int>, note: Int) -> Int {
    return note - notes.startIndex + 1
}

class FeatureCompiler {
    static let eraseLastLineCommand = "\u{1B}[A\u{1B}[2K"
    static let isTTY = isatty(fileno(stdin)) != 0

    struct MonophonicFile {
        let path: String
        let noteNumber: Int
    }
    
    struct PolyphonicFile {
        let audioPath: String
        let midiPath: String?
        let csvPath: String?

        init(audioPath: String, midiPath: String) {
            self.audioPath = audioPath
            self.midiPath = midiPath
            self.csvPath = nil
        }

        init(audioPath: String, csvPath: String) {
            self.audioPath = audioPath
            self.midiPath = nil
            self.csvPath = csvPath
        }
    }
    
    let audioExtensions = [
        "m4a",
        "aiff",
        "mp3",
        "wav",
        "caf"
    ]

    let monophonicFileExpression = try! NSRegularExpression(pattern: "/(\\d+)\\.\\w+", options: NSRegularExpressionOptions.CaseInsensitive)

    let outputFolder: String
    var outputCount = 0
    var fileList = ""

    let decayModel: DecayModel
    let configuration: Configuration

    var polyphonicFiles = [PolyphonicFile]()
    var monophonicFiles = [MonophonicFile]()
    var noiseFiles = [String]()
    
    let queue: NSOperationQueue
    
    init(inputFolder: String, outputFolder: String, configuration: Configuration) {
        self.outputFolder = outputFolder
        self.decayModel = DecayModel(representableNoteRange: configuration.representableNoteRange)
        self.configuration = configuration

        queue = NSOperationQueue()
        queue.name = "Operations"
        queue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount

        let urls = loadFiles(inputFolder)
        (polyphonicFiles, monophonicFiles, noiseFiles) = categorizeURLs(urls)

        print("Window size \(configuration.windowSize), step size \(configuration.stepSize)")
        print("Processing \(polyphonicFiles.count) polyphonic + \(monophonicFiles.count) monophonic + \(noiseFiles.count) noise files\n")
    }

    func compileNoiseFeatures() throws  {
        var completeCount = 0
        for file in noiseFiles {
            queue.addOperationWithBlock {
                self.compileNoiseFeaturesInFile(file)

                dispatch_async(dispatch_get_main_queue()) {
                    completeCount += 1
                    if FeatureCompiler.isTTY {
                        print(FeatureCompiler.eraseLastLineCommand, terminator: "")
                    }
                    print("Noise: \(completeCount) of \(self.noiseFiles.count)")
                }
            }
        }
        while true {
            NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 1))
            if queue.operationCount == 0 {
                break
            }
        }
        print("")
    }

    func compileNoiseFeaturesInFile(file: String) {
        var labels = [Label]()
        var features = [Feature]()

        let exampleBuilder = NoiseSequenceBuilder(path: file, configuration: configuration)
        exampleBuilder.forEachWindow { window in
            labels.append(window.label)
            features.append(window.feature)
        }

        writeLabels(file, labels: labels, features: features, events: [])
    }

    func compileMonoFeatures() throws {
        var completeCount = 0
        for file in monophonicFiles {
            queue.addOperationWithBlock {
                self.compileMonoFeaturesInFile(file)

                dispatch_async(dispatch_get_main_queue()) {
                    completeCount += 1
                    if FeatureCompiler.isTTY {
                        print(FeatureCompiler.eraseLastLineCommand, terminator: "")
                    }
                    print("Mono: \(completeCount) of \(self.monophonicFiles.count)")
                }
            }
        }
        while true {
            NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 1))
            if queue.operationCount == 0 {
                break
            }
        }
        print("")
    }

    func compileMonoFeaturesInFile(file: MonophonicFile) {
        let note = Note(midiNoteNumber: file.noteNumber)
        let exampleBuilder = MonoSequenceBuilder(path: file.path, note: note, decayModel: decayModel, configuration: configuration)

        var labels = [Label]()
        var features = [Feature]()

        exampleBuilder.forEachWindow { window in
            labels.append(window.label)
            features.append(window.feature)
        }

        writeLabels(file.path, labels: labels, features: features, events: [exampleBuilder.event])
    }

    func compilePolyFeatures() throws {
        var completeCount = 0
        for file in polyphonicFiles {
            queue.addOperationWithBlock {
                self.compilePolyFeaturesInFile(file)

                dispatch_async(dispatch_get_main_queue()) {
                    completeCount += 1
                    if FeatureCompiler.isTTY {
                        print(FeatureCompiler.eraseLastLineCommand, terminator: "")
                    }
                    print("Poly: \(completeCount) of \(self.polyphonicFiles.count)")
                }
            }
        }
        while true {
            NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 1))
            if queue.operationCount == 0 {
                break
            }
        }
        print("")
    }

    func compilePolyFeaturesInFile(file: PolyphonicFile) {
        let exampleBuilder: PolySequenceBuilder
        if let midiPath = file.midiPath {
            exampleBuilder = PolySequenceBuilder(audioFilePath: file.audioPath, midiFilePath: midiPath, decayModel: decayModel, configuration: configuration)
        } else if let csvPath = file.csvPath {
            exampleBuilder = PolySequenceBuilder(audioFilePath: file.audioPath, csvFilePath: csvPath, decayModel: decayModel, configuration: configuration)
        } else {
            return
        }

        var labels = [Label]()
        var features = [Feature]()

        exampleBuilder.forEachWindow { window, stop in
            labels.append(window.label)
            features.append(window.feature)
        }

        writeLabels(file.audioPath, labels: labels, features: features, events: exampleBuilder.events)
    }

    func writeLabels(filePath: String, labels: [Label], features: [Feature], events: [Event]) {
        dispatch_sync(dispatch_get_main_queue()) {
            try! self.writeOnMainThread(filePath, labels: labels, features: features, events: events)
        }
    }

    func writeOnMainThread(filePath: String, labels: [Label], features: [Feature], events: [Event]) throws {
        let fileName = String(format: "%.5d.h5", arguments: [outputCount])
        let databasePath = outputFolder.stringByAppendingPathComponent(fileName)
        outputCount += 1

        fileList += "\(filePath), \(databasePath)\n"
        try! fileList.writeToFile(outputFolder.stringByAppendingPathComponent("file_list.txt"), atomically: true, encoding: NSUTF8StringEncoding)

        let database = FeatureDatabase(filePath: databasePath, configuration: configuration)
        try database.writeLabels(labels)
        try database.writeFeatures(features)
        try database.writeEvents(events)
        database.flush()
    }

    func loadFiles(root: String) -> [NSURL] {
        let fileManager = NSFileManager.defaultManager()
        guard let rootURLs = try? fileManager.contentsOfDirectoryAtURL(NSURL.fileURLWithPath(root), includingPropertiesForKeys: [NSURLNameKey], options: NSDirectoryEnumerationOptions.SkipsHiddenFiles) else {
            fatalError()
        }
        
        var isDirectory: ObjCBool = false
        var urls = [NSURL]()
        
        for url in rootURLs {
            if fileManager.fileExistsAtPath(url.path!, isDirectory: &isDirectory) && isDirectory {
                urls.appendContentsOf(loadFiles(url.path!))
            } else {
                if audioExtensions.contains(url.pathExtension!) {
                    urls.append(url)
                }
            }
        }
        
        return urls
    }
    
    func categorizeURLs(urls: [NSURL]) -> (polyphonic: [PolyphonicFile], monophonic: [MonophonicFile], noise: [String]) {
        var polyphonic = [PolyphonicFile]()
        var monophonic = [MonophonicFile]()
        var noise = [String]()
        
        for url in urls {
            if let polyPath = polyPath(url) {
                polyphonic.append(polyPath)
            } else if let monoPath = monoPath(url) {
                monophonic.append(monoPath)
            } else {
                noise.append(url.path!)
            }
        }
        
        return (polyphonic: polyphonic, monophonic: monophonic, noise: noise)
    }
    
    func monoPath(url: NSURL) -> MonophonicFile? {
        let path = url.path!
        
        guard let results = monophonicFileExpression.firstMatchInString(path, options: NSMatchingOptions.ReportCompletion, range: NSMakeRange(0, path.characters.count)) else {
            return nil
        }
        if results.numberOfRanges < 1 {
            return nil
        }
        let range = results.rangeAtIndex(1)
        
        let fileName = (path as NSString).substringWithRange(range)
        guard let noteNumber = Int(fileName) else {
            return nil
        }
        
        return MonophonicFile(path: path, noteNumber: noteNumber)
    }
    
    func polyPath(url: NSURL) -> PolyphonicFile? {
        let manager = NSFileManager.defaultManager()
        guard let midFile = url.URLByDeletingPathExtension?.URLByAppendingPathExtension("mid") else {
            fatalError("Failed to build path")
        }
        
        if manager.fileExistsAtPath(midFile.path!) {
            return PolyphonicFile(audioPath: url.path!, midiPath: midFile.path!)
        }

        guard let csvFile = url.URLByDeletingPathExtension?.URLByAppendingPathExtension("csv") else {
            fatalError("Failed to build path")
        }

        if manager.fileExistsAtPath(csvFile.path!) {
            return PolyphonicFile(audioPath: url.path!, csvPath: csvFile.path!)
        }
        
        return nil
    }
}
