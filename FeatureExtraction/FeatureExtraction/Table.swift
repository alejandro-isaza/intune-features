//  Copyright © 2015 Venture Media. All rights reserved.

import Foundation
import HDF5Kit
import Upsurge

/// `Table` represents a 2-dimensional data set of doubles in an HDF5 file
public class Table {
    public enum Error: ErrorType {
        case DatasetNotFound
        case DatasetNotCompatible
    }

    public let file: File
    public let name: String
    public let rowSize: Int
    public let chunkSize: Int

    /// Create or open a table
    public init(file: File, name: String, rowSize: Int, chunkSize: Int = 1024) {
        self.file = file
        self.name = name
        self.rowSize = rowSize
        self.chunkSize = chunkSize

        if let dataset = file.openDoubleDataset(name) {
            verifyDataset(dataset)
        } else {
            createDataset()
        }
    }

    func verifyDataset(dataset: DoubleDataset) {
        guard let nativeType = dataset.type.nativeType else {
            preconditionFailure("Existing dataset '\(name)' is not of a native data type")
        }
        precondition(nativeType == .Double, "Existing dataset '\(name)' is of the wrong type")

        let dims = dataset.space.dims
        precondition(dims.count == 2 && dims[1] == rowSize, "Existing dataset '\(name)' is of the wrong size. Expected \(rowSize) got \(dims[1]).")
    }

    func createDataset() {
        let space = Dataspace(dims: [0, rowSize], maxDims: [-1, rowSize])
        file.createDoubleDataset(name, dataspace: space, chunkDimensions: [chunkSize, rowSize])
    }

    /// The number of rows in the table
    public var rowCount: Int {
        guard let dataset = file.openDoubleDataset(name) else {
            return 0
        }

        return dataset.space.dims[0]
    }

    /// Read rows from the table
    ///
    /// - parameter start:   The index of the first row to read. Must be less than `rowCount`.
    /// - parameter count:   The number of rows to read.
    /// - parameter pointer: The location in memory where the results are going to be stored. There must be enough space for `count * rowSize` elements.
    ///
    /// - returns: The number of rows read, at most `count`.
    public func readFromRow(start: Int, count: Int, into pointer: UnsafeMutablePointer<Double>) throws -> Int {
        guard let dataset = file.openDoubleDataset(name) else {
            throw Error.DatasetNotFound
        }

        let fileSpace = Dataspace(dataset.space)
        guard fileSpace.dims[1] == rowSize else {
            throw Error.DatasetNotCompatible
        }
        let actualCount = min(fileSpace.dims[0], count)
        fileSpace.select(start: [start, 0], stride: nil, count: [actualCount, rowSize], block: nil)

        let memSpace = Dataspace(dims: [actualCount, rowSize])
        try dataset.readInto(pointer, memSpace: memSpace, fileSpace: fileSpace)

        return actualCount
    }

    /// Append data to the table
    public func appendData<C: TensorType where C.Element == Double>(data: C) throws {
        guard let dataset = file.openDoubleDataset(name) else {
            throw Error.DatasetNotFound
        }

        let newRows = data.count / rowSize
        let currentSize = dataset.extent[0]
        dataset.extent[0] += newRows

        let fileSpace = dataset.space
        guard fileSpace.dims[1] == rowSize else {
            throw Error.DatasetNotCompatible
        }
        fileSpace.select(start: [currentSize, 0], stride: nil, count: [newRows, rowSize], block: nil)

        let memSpace = Dataspace(dims: [newRows, rowSize])

        try dataset.writeFrom(data.pointer, memSpace: memSpace, fileSpace: fileSpace)
    }

    /// Overwrite data
    ///
    /// - precondition: `start + ⌊data.count / rowSize⌋ ≤ rowCount`
    ///
    /// - parameter start: The index of the first row to overwrite. Must be less than `rowCount`.
    /// - parameter data:  The new data.
    public func overwriteFromRow<C: TensorType where C.Element == Double>(start: Int, with data: C) throws {
        guard let dataset = file.openDoubleDataset(name) else {
            throw Error.DatasetNotFound
        }

        let newRows = data.count / rowSize
        let fileSpace = dataset.space
        guard fileSpace.dims[1] == rowSize else {
            throw Error.DatasetNotCompatible
        }
        precondition(start + data.count / rowSize <= fileSpace.dims[0])
        fileSpace.select(start: [start, 0], stride: nil, count: [newRows, rowSize], block: nil)

        let memSpace = Dataspace(dims: [newRows, rowSize])

        try dataset.writeFrom(data.pointer, memSpace: memSpace, fileSpace: fileSpace)
    }
}
