import XCTest
@testable import Kitura_HTTP2

class Kitura_HTTP2Tests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(Kitura_HTTP2().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
