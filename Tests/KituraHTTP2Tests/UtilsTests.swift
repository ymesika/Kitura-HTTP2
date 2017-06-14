//
//  UtilsTests.swift
//  Kitura-HTTP2
//
//  Created by Yossi Mesika on 14/6/17.
//
//

import XCTest
@testable import KituraHTTP2

class UtilsTests: XCTestCase {
    
    static var allTests : [(String, (UtilsTests) -> () throws -> Void)] {
        return [
            ("testBase64urlToBase64", testBase64urlToBase64),
            ("testDataAsHexString", testDataAsHexString)
        ]
    }
    
    func testBase64urlToBase64() {
        XCTAssertEqual(HTTP2Utils.base64urlToBase64(base64url: ""), "")
        XCTAssertEqual(HTTP2Utils.base64urlToBase64(base64url: "This-is_goingto-escape"), "This+is/goingto+escape==")
    }
    
    func testDataAsHexString() {
        let bytes: [UInt8] = [0x54, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x20, 0x74, 0x65, 0x73, 0x74, 0x20, 0x73, 0x74, 0x72, 0x69, 0x6e, 0x67]
        bytes.withUnsafeBytes() { ptr in
            let data = NSData(bytes: bytes, length: bytes.count)
            XCTAssertEqual(HTTP2Utils.dataAsHexString(data: data), "546869732069732061207465737420737472696e67")
        }
    }
    
}
