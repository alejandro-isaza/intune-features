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
        let midiPath: String
    }
    
    let audioExtensions = [
        "m4a",
        "aiff",
        "mp3",
        "wav",
        "caf"
    ]

    let monophonicFileExpression = try! NSRegularExpression(pattern: "/(\\d+)\\.\\w+", options: NSRegularExpressionOptions.CaseInsensitive)
    
    let database: FeatureDatabase
    
    var existingFiles: Set<String>
    var featureBuilder = FeatureBuilder()
    
    var polyphonicFiles = [PolyphonicFile]()
    var monophonicFiles = [MonophonicFile]()
    var noiseFiles = [String]()

    init(root: String, output: String, overwrite: Bool) {
        database = FeatureDatabase(filePath: output, overwrite: overwrite)
        existingFiles = database.fileList
        let urls = loadFiles(root)
        (polyphonicFiles, monophonicFiles, noiseFiles) = categorizeURLs(urls)

        print("\nWorking Directory: \(NSFileManager.defaultManager().currentDirectoryPath)")
        print("Processing \(polyphonicFiles.count) polyphonic + \(monophonicFiles.count) monophonic + \(noiseFiles.count) noise files\n")
    }

    func compileNoiseFeatures() throws {
        let exampleBuilder = MonoExampleBuilder()
        for (i, file) in noiseFiles.enumerate() {
            if FeatureCompiler.isTTY {
                print(FeatureCompiler.eraseLastLineCommand, terminator: "")
            }
            print("Noise: \(i + 1) of \(noiseFiles.count)")
            guard !existingFiles.contains(file) else {
                continue
            }

            var features = [FeatureData]()
            exampleBuilder.forEachExampleInFile(file, note: nil, numExamples: MonoExampleBuilder.numNoiseExamples, action: { example in
                let featureData = FeatureData(filePath: example.filePath, fileOffset: example.frameOffset, label: example.label)
                featureData.feature = self.featureBuilder.generateFeatures(example.data.0, example.data.1)
                features.append(featureData)
                self.existingFiles.unionInPlace([example.filePath])
            })

            try database.appendFeatures(features)
        }
        print("")
    }

    func compileMonoFeatures() throws {
        let exampleBuilder = MonoExampleBuilder()
        for (i, file) in monophonicFiles.enumerate() {
            if FeatureCompiler.isTTY {
                print(FeatureCompiler.eraseLastLineCommand, terminator: "")
            }
            print("Mono: \(i + 1) of \(monophonicFiles.count)")
            guard !existingFiles.contains(file.path) else {
                continue
            }
            
            var features = [FeatureData]()
            let note = Note(midiNoteNumber: file.noteNumber)
            exampleBuilder.forEachExampleInFile(file.path, note: note, numExamples: MonoExampleBuilder.numNoteExamples, action: { example in
                let featureData = FeatureData(filePath: example.filePath, fileOffset: example.frameOffset, label: example.label)
                featureData.feature = self.featureBuilder.generateFeatures(example.data.0, example.data.1)
                features.append(featureData)
                self.existingFiles.unionInPlace([example.filePath])
            })

            try database.appendFeatures(features)
        }
        print("")
    }

    func compilePolyFeatures() throws {
        let exampleBuilder = PolyExampleBuilder()
        for (i, file) in polyphonicFiles.enumerate() {
            if FeatureCompiler.isTTY {
                print(FeatureCompiler.eraseLastLineCommand, terminator: "")
            }
            print("Poly: \(i + 1) of \(polyphonicFiles.count)")
            guard !existingFiles.contains(file.audioPath) else {
                continue
            }
            
            var features = [FeatureData]()
            exampleBuilder.forEachExampleInAudioFile(file.audioPath, midiFilePath: file.midiPath, action: { example in
                let featureData = FeatureData(filePath: example.filePath, fileOffset: example.frameOffset, label: example.label)
                featureData.feature = self.featureBuilder.generateFeatures(example.data.0, example.data.1)
                features.append(featureData)
                self.existingFiles.unionInPlace([example.filePath])
            })
            
            try database.appendFeatures(features)
        }
        print("")
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
        
        return nil
    }
    
    func shuffle(chunkSize chunkSize: Int, passes: Int) throws {
        print("Shuffling...")
        try database.shuffle(chunkSize: chunkSize, passes: passes) { progress in
            if FeatureCompiler.isTTY {
                print("\(FeatureCompiler.eraseLastLineCommand)Shuffling database data...\(round(progress * 10000) / 100)%")
            }
        }
        print("")
    }
}
