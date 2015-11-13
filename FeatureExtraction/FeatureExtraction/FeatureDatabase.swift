//  Copyright © 2015 Venture Media. All rights reserved.

import HDF5Kit
import Upsurge

public class FeatureDatabase {
    let filePath: String
    let overwrite: Bool

    var datasets = [
        "rms": RealArray(count: 0),
        "peak_locations": RealArray(count: 0),
        "peak_heights": RealArray(count: 0),
        "spectrum": RealArray(count: 0),
        "spectrum_flux": RealArray(count: 0)
    ]
    public internal(set) var folders = [String]()
    public internal(set) var fileNames = [String]()
    public internal(set) var offsets = [Int]()
    public internal(set) var labels = [Int]()
    public internal(set) var exampleCount = 0

    public init(filePath: String, overwrite: Bool) {
        self.filePath = filePath
        self.overwrite = overwrite

        if !overwrite {
            if let file = File.open(filePath, mode: .ReadWrite) {
                load(file)
            }
        }
    }

    func load(file: HDF5Kit.File) {
        if let folders = file.openDataset("folders")?.readString() {
            self.folders = folders
        } else {
            self.folders.removeAll()
        }

        if let fileNames = file.openDataset("fileName")?.readString() {
            self.fileNames = fileNames
        } else {
            fileNames.removeAll()
        }

        if let offsets = file.openDataset("offset")?.readInt() {
            self.offsets = offsets
        } else {
            offsets.removeAll()
        }

        for datasetName in datasets.keys {
            guard let dataset = file.openDataset(datasetName) else {
                datasets[datasetName]!.count = 0
                continue
            }

            let space = dataset.space
            let size = Int(space.size)
            exampleCount = Int(space.dims[0])

            var array = datasets[datasetName]!
            if array.capacity < size {
                array = RealArray(count: size)
            }

            dataset.readDouble(array.mutablePointer)
        }
    }

    public func appendFeatures(features: [FeatureData], folder: String?) {
        guard let exampleFeature = features.first else {
            return
        }
        exampleCount += features.count

        guard let file = File.create(filePath, mode: .Truncate) else {
            fatalError("Failed to create new HDF5 file")
        }

        for datasetName in datasets.keys {
            guard let exampleDataset = exampleFeature.features[datasetName] else {
                fatalError("Feature missing \(datasetName)")
            }
            appendFeatures(features, forDataset: datasetName, toFile: file, featureSize: exampleDataset.count)
        }

        appendLabels(features, toFile: file, featureSize: exampleFeature.example.label.count)
        appendOffsets(features, toFile: file)
        appendFileNames(features, toFile: file)
        if let folder = folder {
            appendFolder(folder, toFile: file)
        }
    }

    func appendFeatures(features: [FeatureData], forDataset datasetName: String, toFile file: File, featureSize: Int) {
        // Allocate space for the new features
        let oldArray = datasets[datasetName]!
        let newArray = RealArray(capacity: exampleCount * featureSize)
        newArray.mutablePointer.assignFrom(oldArray.mutablePointer, count: oldArray.count)
        newArray.count = oldArray.count
        datasets[datasetName] = newArray

        // Create dataset
        let space = Dataspace(dims: [exampleCount, featureSize])
        let dataset = file.createDataset(datasetName, datatype: Datatype.createDouble(), dataspace: space)

        for featureData in features {
            guard let data = featureData.features[datasetName] else {
                fatalError("Feature is missing dataset \(datasetName)")
            }
            newArray.appendContentsOf(data)
        }
        dataset.writeDouble(newArray.pointer)
    }

    func appendLabels(features: [FeatureData], toFile file: File, featureSize: Int) {
        let datasetName = "label"
        labels.reserveCapacity(exampleCount * featureSize)

        // Create dataset
        let space = Dataspace(dims: [exampleCount, featureSize])
        let dataset = file.createDataset(datasetName, datatype: Datatype.createInt(), dataspace: space)

        for feature in features {
            labels.appendContentsOf(feature.example.label)
        }
        dataset.writeInt(labels.pointer)
    }

    func appendOffsets(features: [FeatureData], toFile file: File) {
        let datasetName = "offset"
        offsets.reserveCapacity(exampleCount)

        // Create dataset
        let space = Dataspace(dims: [exampleCount])
        let dataset = file.createDataset(datasetName, datatype: Datatype.createInt(), dataspace: space)

        for feature in features {
            offsets.append(feature.example.frameOffset)
        }
        dataset.writeInt(offsets.pointer)
    }

    func appendFileNames(features: [FeatureData], toFile file: File) {
        let datasetName = "fileName"
        fileNames.reserveCapacity(exampleCount)

        // Create dataset
        let space = Dataspace(dims: [exampleCount])
        let dataset = file.createDataset(datasetName, datatype: Datatype.createString(), dataspace: space)

        for feature in features {
            fileNames.append(feature.example.filePath)
        }
        dataset.writeString(fileNames)
    }

    func appendFolder(folder: String, toFile file: File) {
        folders.append(folder)

        // Create dataset
        let datasetName = "folders"
        let space = Dataspace(dims: [folders.count])
        let dataset = file.createDataset(datasetName, datatype: Datatype.createString(), dataspace: space)
        dataset.writeString(folders)
    }
}
