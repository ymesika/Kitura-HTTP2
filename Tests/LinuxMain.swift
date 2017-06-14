import XCTest

@testable import KituraHTTP2Tests

XCTMain([
    testCase(LargePayloadTests.allTests),
    testCase(ClientE2ETests.allTests),
])
