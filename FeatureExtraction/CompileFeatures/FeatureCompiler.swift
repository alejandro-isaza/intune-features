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

        print("\nWorking Directory: \(NSFileManager.defaultManager().currentDirectoryPath)\n")
    }

    func compileNoiseFeatures() {
        let exampleBuilder = MonoExampleBuilder()
        for file in noiseFiles {
            var features = [FeatureData]()
            let label = [Int](count: FeatureBuilder.notes.count, repeatedValue: 0)
            exampleBuilder.forEachExampleInFile(file, label: label, numExamples: MonoExampleBuilder.numNoiseExamples, action: { example in
                let featureData = FeatureData(filePath: example.filePath, fileOffset: example.frameOffset, label: example.label)
                featureData.features = self.featureBuilder.generateFeatures(example)
                features.append(featureData)
                self.existingFiles.unionInPlace([example.filePath])
            })

            database.appendFeatures(features)
        }
    }

    func compileMonoFeatures() {
        let exampleBuilder = MonoExampleBuilder()
        for file in monophonicFiles {
            guard !existingFiles.contains(file.path) else {
                continue
            }
            
            var features = [FeatureData]()
            let label = FeatureBuilder.labelForNote(file.noteNumber)
            exampleBuilder.forEachExampleInFile(file.path, label: label, numExamples: MonoExampleBuilder.numNoteExamples, action: { example in
                let featureData = FeatureData(filePath: example.filePath, fileOffset: example.frameOffset, label: example.label)
                featureData.features = self.featureBuilder.generateFeatures(example)
                features.append(featureData)
                self.existingFiles.unionInPlace([example.filePath])
            })

            database.appendFeatures(features)
        }
    }

    func compilePolyFeatures() {
        let exampleBuilder = PolyExampleBuilder()
        for file in polyphonicFiles {
            guard !existingFiles.contains(file.audioPath) else {
                continue
            }
            
            var features = [FeatureData]()
            exampleBuilder.forEachExampleInAudioFile(file.audioPath, midiFilePath: file.midiPath, action: { example in
                let featureData = FeatureData(filePath: example.filePath, fileOffset: example.frameOffset, label: example.label)
                featureData.features = self.featureBuilder.generateFeatures(example)
                features.append(featureData)
                self.existingFiles.unionInPlace([example.filePath])
            })
            
            database.appendFeatures(features)
        }
    }

    func loadFiles(root: String) -> [NSURL] {
        let fileManager = NSFileManager.defaultManager()
        print(fileManager.currentDirectoryPath)
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
        let noteNumberRegex = try! NSRegularExpression(pattern: "/(\\d+)\\.\\w+", options: NSRegularExpressionOptions.CaseInsensitive)
        
        guard let results = noteNumberRegex.firstMatchInString(path, options: NSMatchingOptions.ReportCompletion, range: NSMakeRange(0, path.characters.count)) else {
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
        let extensionRegex = try! NSRegularExpression(pattern: "\(audioExtensions.joinWithSeparator("|"))", options: NSRegularExpressionOptions.CaseInsensitive)
        
        let path = extensionRegex.stringByReplacingMatchesInString(url.path!, options: NSMatchingOptions.ReportCompletion, range: NSMakeRange(0, url.path!.characters.count), withTemplate: "mid")
        
        let midFile = NSURL.fileURLWithPath(path)
        if manager.fileExistsAtPath(midFile.path!) {
            return PolyphonicFile(audioPath: url.path!, midiPath: midFile.path!)
        }
        
        return nil
    }
    
    func shuffle(chunkSize chunkSize: Int, passes: Int) {
        let isTTY = isatty(fileno(stdin)) != 0
        let eraseLastLineCommand = "\u{1B}[A\u{1B}[2K"

        if isTTY {
            print("Shuffling...")
        }

        database.shuffle(chunkSize: chunkSize, passes: passes) { progress in
            if isTTY {
                print("\(eraseLastLineCommand)Shuffling database data...\(round(progress * 10000) / 100)%")
            }
        }
    }
}
