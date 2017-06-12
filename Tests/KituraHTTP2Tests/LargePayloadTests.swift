/**
 * Copyright IBM Corporation 2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation

import XCTest

@testable import KituraHTTP2

import Socket
import KituraNet
import CCurl

class LargePayloadTests: KituraHTTP2Test {

    static var allTests : [(String, (LargePayloadTests) -> () throws -> Void)] {
        return [
            ("testLargePost", testLargePost),
            ("testLargeGet", testLargeGet),
            ("testSecuredLargePost", testSecuredLargePost),
            ("testSecuredLargeGet", testSecuredLargeGet)
        ]
    }

    override func setUp() {
        doSetUp()
    }

    override func tearDown() {
        doTearDown()
    }

    private let delegate = TestServerDelegate()

    func testLargePost() {
		largePost(secured: false)
    }

    func testLargeGet() {
		largeGet(secured: false)
	}
	
	func testSecuredLargePost() {
		largePost(secured: true)
	}
	
	func testSecuredLargeGet() {
		largeGet(secured: true)
	}
	
	private func largePost(secured: Bool) {
		performServerTest(delegate, useSSL: secured, asyncTasks: { expectation in
			let payload = "[" + contentTypesString + "," + contentTypesString + contentTypesString + "," + contentTypesString + "]"
			self.performRequest("post", path: "/largepost", callback: {response in
				XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
				do {
					let expectedResult = "Read \(payload.characters.count) bytes"
					var data = Data()
					let count = try response?.readAllData(into: &data)
					XCTAssertEqual(count, expectedResult.characters.count, "Result should have been \(expectedResult.characters.count) bytes, was \(String(describing: count)) bytes")
					let postValue = String(data: data, encoding: .utf8)
					if  let postValue = postValue {
						XCTAssertEqual(postValue, expectedResult)
					}
					else {
						XCTFail("postValue's value wasn't an UTF8 string")
					}
				}
				catch {
					XCTFail("Failed reading the body of the response")
				}
				expectation.fulfill()
			}) {request in
				request.write(from: payload)
			}
		})
	}
	
	private func largeGet(secured: Bool) {
		performServerTest(delegate, useSSL: secured, asyncTasks: { expectation in
			self.performRequest("post", path: "/largepost", callback: { response in
				XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "Status code wasn't .Ok was \(String(describing: response?.statusCode))")
				expectation.fulfill()
			})
		})
	}

    private class TestServerDelegate : ServerDelegate {

        func handle(request: ServerRequest, response: ServerResponse) {
            if  request.method.uppercased() == "GET" {
                handleGet(request: request, response: response)
            }
            else {
                handlePost(request: request, response: response)
            }
        }

        func handleGet(request: ServerRequest, response: ServerResponse) {
            var payload = "[" + contentTypesString
            for _ in 0 ... 320 {
                payload += "," + contentTypesString
            }
            payload += "]"
            let payloadData = payload.data(using: .utf8)!
            do {
                response.headers["Content-Length"] = ["\(payloadData.count)"]
                try response.write(from: payloadData)
                try response.end()
            }
            catch {
                print("Error writing response.")
            }
        }

        func handlePost(request: ServerRequest, response: ServerResponse) {
            var body = Data()
            do {
                let length = try request.readAllData(into: &body)
                let result = "Read \(length) bytes"
                response.headers["Content-Type"] = ["text/plain"]
                response.headers["Content-Length"] = ["\(result.characters.count)"]

                try response.end(text: result)
            }
            catch {
                print("Error reading body or writing response")
            }
        }
    }
}
