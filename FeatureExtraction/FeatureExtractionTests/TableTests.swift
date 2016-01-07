//  Copyright © 2015 Venture Media. All rights reserved.

import FeatureExtraction
import HDF5Kit
import XCTest
import Upsurge

class TableTests: XCTestCase {
    let datasetName = "test"

    func testCreate() {
        let fileName = "TableTests.\(__FUNCTION__).h5"
        let file = File.create(fileName, mode: .Truncate)!
        let _ = Table(file: file, name: datasetName, rowSize: 10)
        XCTAssertNotNil(file.openDoubleDataset(datasetName))
    }

    func testAppend() {
        let fileName = "TableTests.\(__FUNCTION__).h5"
        let rowCount = 10
        let rowSize = 10
        let testData = [Double]((0..<rowCount * rowSize).map({ Double($0) }))

        let file = File.create(fileName, mode: .Truncate)!
        let table = Table(file: file, name: datasetName, rowSize: rowSize, chunkSize: rowCount)
        do {
            try table.appendData(testData)
            XCTAssertEqual(table.rowCount, rowCount)
        } catch let error {
            XCTFail("Error when appending: \(error)")
        }
        file.flush()

        let readFile = File.open(fileName, mode: .ReadOnly)!
        let dataset = readFile.openDoubleDataset(datasetName)!
        let readData = try! dataset.read()

        XCTAssertEqual(readData, testData)
    }

    func testRead() {
        let fileName = "TableTests.\(__FUNCTION__).h5"
        let rowCount = 10
        let rowSize = 10
        let testData = RealArray((0..<rowCount * rowSize).map({ Double($0) }))

        do {
            let file = File.create(fileName, mode: .Truncate)!
            let table = Table(file: file, name: datasetName, rowSize: rowSize, chunkSize: rowCount)
            try table.appendData(testData)
            file.flush()
        } catch let error {
            XCTFail("Error when appending: \(error)")
        }

        do {
            let file = File.open(fileName, mode: .ReadOnly)!
            let table = Table(file: file, name: datasetName, rowSize: rowSize, chunkSize: rowCount)
            let readData = RealArray(capacity: testData.count)
            readData.count = try table.readFromRow(0, count: 10, into: readData.mutablePointer) * rowSize
            XCTAssertEqual(readData, testData)
        } catch let error {
            XCTFail("Error when reading: \(error)")
        }
    }

    func testOverwrite() {
        let fileName = "TableTests.\(__FUNCTION__).h5"
        let rowCount = 10
        let rowSize = 10
        let testData = RealArray((0..<rowCount * rowSize).map({ Double($0) }))

        // Create table
        do {
            let file = File.create(fileName, mode: .Truncate)!
            let table = Table(file: file, name: datasetName, rowSize: rowSize, chunkSize: rowCount)
            try table.appendData(testData)
            file.flush()
        } catch let error {
            XCTFail("Error when appending: \(error)")
        }

        // Overwrite data
        let overwriteData = RealArray((0..<10).map({ Double($0) }))
        do {
            let file = File.open(fileName, mode: .ReadWrite)!
            let table = Table(file: file, name: datasetName, rowSize: rowSize, chunkSize: rowCount)
            try table.overwriteFromRow(5, with: overwriteData)
            file.flush()
        } catch let error {
            XCTFail("Error when overwriting: \(error)")
        }

        // Verify
        do {
            let file = File.open(fileName, mode: .ReadOnly)!
            let table = Table(file: file, name: datasetName, rowSize: rowSize, chunkSize: rowCount)
            let readData = RealArray(capacity: testData.count)
            readData.count = try table.readFromRow(0, count: 10, into: readData.mutablePointer) * rowSize
            XCTAssertEqual(readData[0..<50], testData[0..<50])
            XCTAssertEqual([Double](other: readData[50..<60]), [Double](other: overwriteData))
            XCTAssertEqual(readData[60..<100], testData[60..<100])
        } catch let error {
            XCTFail("Error when reading: \(error)")
        }
    }

}
