//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import Upsurge
import HDF5Kit

public class FeatureDataCompiler {
    public var exampleCount: Int
    public var labels: [[Int]]
    public var fileNames: [String]
    public var offsets: [Int]
    public var data: [String: RealArray]

    init(exampleCount: Int) {
        self.exampleCount = exampleCount

        labels = [[Int]]()
        labels.reserveCapacity(exampleCount)
        fileNames = [String]()
        fileNames.reserveCapacity(exampleCount)
        offsets = [Int]()
        offsets.reserveCapacity(exampleCount)
        
        data = [String: RealArray]()
    }
    
    public convenience init() {
        self.init(exampleCount: 0)
    }

    public convenience init(features: [FeatureData]) {
        self.init(exampleCount: features.count)

        for featureData in features {
            labels.append(featureData.example.label)
            offsets.append(featureData.example.frameOffset)
            fileNames.append(featureData.example.filePath)
            
            let features = featureData.features
            for (name, data) in features {
                if let allData = self.data[name] {
                    for var i = 0; i < data.count; i += 1 {
                        allData.append(data[i])
                    }
                } else {
                    let allData = RealArray(capacity: exampleCount * data.count)
                    for var i = 0; i < data.count; i += 1 {
                        allData.append(data[i])
                    }
                    self.data[name] = allData
                }
            }
        }
    }
    
    public func writeToHDF5(fileName: String, noteRange: Range<Int>, folders: [String]) {
        guard let hdf5File = HDF5Kit.File.create(fileName, mode: File.CreateMode.Truncate) else {
            fatalError("Failed to open HDF5 file")
        }
        
        for (name, value) in self.data {
            let featureSize = UInt64(value.count / self.offsets.count)
            let dataType = Datatype.copy(type: .Double)
            print(value.count)
            let dataDataspace = Dataspace(dims: [UInt64(self.offsets.count), featureSize])
            let dataDataset = hdf5File.createDataset(name, datatype: dataType, dataspace: dataDataspace)
            dataDataset.writeDouble(value.pointer)
        }
        
//        let flattenedDoubleLabels = self.labels.reduce([Double]()){ (var a: [Double], b: [Int]) in
//            a.appendContentsOf(b.map{ Double($0) })
//            return a
//        }
//        let labelMatrix = RealMatrix(rows: labels.count, columns: labels[0].count, elements: flattenedDoubleLabels)
        for i in 0..<noteRange.count {
            let labelDataspace = Dataspace(dims: [labels.count, 1])
            let labelsDataset = hdf5File.createDataset("label\(i)", datatype: Datatype.createInt(), dataspace: labelDataspace)
            
//            let labels = labelMatrix.column(i).map{ Int($0) }
            var labelData = [Int]()
            for j in 0..<labels.count {
                labelData.append(Int(labels[j][i]))
            }
            labelsDataset.writeInt(labelData)
        }
        
        let offsetDataspace = Dataspace(dims: [self.offsets.count])
        let offsetDataset = hdf5File.createDataset("offset", datatype: Datatype.createInt(), dataspace: offsetDataspace)
        offsetDataset.writeInt(self.offsets)
        
        let fileDataspace = Dataspace(dims: [self.fileNames.count])
        let fileDataset = hdf5File.createDataset("fileName", datatype: Datatype.createString(), dataspace: fileDataspace)
        fileDataset.writeString(self.fileNames)
        
        let foldersDataspace = Dataspace(dims: [folders.count])
        let foldersDataset = hdf5File.createDataset("folders", datatype: Datatype.createString(), dataspace: foldersDataspace)
        foldersDataset.writeString(folders)
    }
}
