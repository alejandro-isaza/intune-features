// Copyright © 2016 Venture Media Labs.
//
// This file is part of IntuneFeatures. The full IntuneFeatures copyright
// notice, including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation

import Peak
import IntuneFeatures
import HDF5Kit
import Upsurge

func midiNoteLabel(_ notes: Range<Int>, note: Int) -> Int {
    return note - notes.lowerBound + 1
}

class FeatureCompiler {
    static let eraseLastLineCommand = "\u{1B}[A\u{1B}[2K"
    static let isTTY = isatty(fileno(stdin)) != 0
    
    struct InputFile {
        let audioPath: String
        let midiPath: String?

        init(audioPath: String, midiPath: String) {
            self.audioPath = audioPath
            self.midiPath = midiPath
        }

        init(audioPath: String, csvPath: String) {
            self.audioPath = audioPath
            self.midiPath = nil
        }
    }
    
    let audioExtensions = [
        "m4a",
        "aiff",
        "mp3",
        "wav",
        "caf"
    ]

    let outputFolder: String
    var outputCount = 0
    var fileList = ""

    let decayModel: DecayModel
    let configuration: Configuration

    var inputFiles = [InputFile]()
    
    let queue: OperationQueue
    
    init(inputFolder: String, outputFolder: String, configuration: Configuration) {
        self.outputFolder = outputFolder
        self.decayModel = DecayModel(representableNoteRange: configuration.representableNoteRange)
        self.configuration = configuration

        queue = OperationQueue()
        queue.name = "Operations"
        queue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount

        let urls = loadFiles(inputFolder)
        for url in urls {
            if let inputFile = inputFileForURL(url) {
                inputFiles.append(inputFile)
            }
        }

        print("Window size \(configuration.windowSize), step size \(configuration.stepSize)")
        print("Processing \(inputFiles.count) files\n")
    }

    func compileFeatures() throws {
        var completeCount = 0
        for file in inputFiles {
            queue.addOperation {
                self.compileFeaturesInFile(file)

                DispatchQueue.main.async {
                    completeCount += 1
                    if FeatureCompiler.isTTY {
                        print(FeatureCompiler.eraseLastLineCommand, terminator: "")
                    }
                    print("File: \(completeCount) of \(self.inputFiles.count)")
                }
            }
        }
        while true {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
            if queue.operationCount == 0 {
                break
            }
        }
        print("")
    }

    func compileFeaturesInFile(_ file: InputFile) {
        let builder: Builder
        if let midiPath = file.midiPath {
            builder = PolySequenceBuilder(audioFilePath: file.audioPath, midiFilePath: midiPath, decayModel: decayModel, configuration: configuration)
        } else {
            builder = NoiseSequenceBuilder(audioFilePath: file.audioPath, configuration: configuration)
        }

        var labels = [Label]()
        var features = [Feature]()

        builder.forEachWindow { window in
            labels.append(window.label)
            features.append(window.feature)
        }

        writeLabels(file.audioPath, labels: labels, features: features, events: builder.events)
    }

    func writeLabels(_ filePath: String, labels: [Label], features: [Feature], events: [Event]) {
        DispatchQueue.main.sync {
            try! self.writeOnMainThread(filePath, labels: labels, features: features, events: events)
        }
    }

    func writeOnMainThread(_ filePath: String, labels: [Label], features: [Feature], events: [Event]) throws {
        let fileName = String(format: "%.5d.h5", arguments: [outputCount])
        let databasePath = outputFolder.stringByAppendingPathComponent(fileName)
        outputCount += 1

        fileList += "\(filePath), \(databasePath)\n"
        try! fileList.write(toFile: outputFolder.stringByAppendingPathComponent("file_list.txt"), atomically: true, encoding: String.Encoding.utf8)

        let database = FeatureDatabase(filePath: databasePath, configuration: configuration)
        try database.writeLabels(labels)
        try database.writeFeatures(features)
        try database.writeEvents(events)
        database.flush()
    }

    func loadFiles(_ root: String) -> [URL] {
        let fileManager = FileManager.default
        guard let rootURLs = try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [URLResourceKey.nameKey], options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles) else {
            fatalError()
        }
        
        var isDirectory: ObjCBool = false
        var urls = [URL]()
        
        for url in rootURLs {
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                urls.append(contentsOf: loadFiles(url.path))
            } else {
                if audioExtensions.contains(url.pathExtension) {
                    urls.append(url)
                }
            }
        }
        
        return urls
    }
    
    func inputFileForURL(_ url: URL) -> InputFile? {
        let manager = FileManager.default
        let midFile = url.deletingPathExtension().appendingPathExtension("mid")
        if manager.fileExists(atPath: midFile.path) {
            return InputFile(audioPath: url.path, midiPath: midFile.path)
        }

        let csvFile = url.deletingPathExtension().appendingPathExtension("csv")
        if manager.fileExists(atPath: csvFile.path) {
            return InputFile(audioPath: url.path, csvPath: csvFile.path)
        }
        
        return nil
    }
}
