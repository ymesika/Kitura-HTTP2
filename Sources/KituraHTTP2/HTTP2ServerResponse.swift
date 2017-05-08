/*
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
 */

import Foundation

import KituraNet
import nghttp2

class HTTP2ServerResponse: ServerResponse {
    
    /// The status code to send in the HTTP response.
    var statusCode: HTTPStatusCode?
    
    /// The headers to send back as part of the HTTP response.
    var headers = HeadersContainer()
    
    var headersStrings = [[UInt8]]()
    var frameData: Data? = nil
    
    let http2Session: Http2Session
    let stream: Int32
    
    init(session: Http2Session, streamId: Int32) {
        http2Session = session
        stream = streamId
        headers["Date"] = [SPIUtils.httpDate()]
    }
    
    /// Add a string to the body of the HTTP response.
    ///
    /// - Parameter string: The String data to be added.
    ///
    /// - Throws: Socket.error if an error occurred while writing to the socket
    func write(from string: String) throws {
        //TODO is it correct to assume UTF8?
        if let data = string.data(using: .utf8) {
            try write(from: data)
        }
    }
    
    /// Add bytes to the body of the HTTP response.
    ///
    /// - Parameter data: The Data struct that contains the bytes to be added.
    ///
    /// - Throws: Socket.error if an error occurred while writing to the socket
    func write(from data: Data) throws {
        //http2Session.sendData(streamId: stream, data: data, headers: nghttp2Headers())
        if frameData == nil {
            frameData = Data()
        }
        frameData?.append(data)
    }
    
    /// Add a string to the body of the HTTP response and complete sending the HTTP response
    ///
    /// - Parameter text: The String to add to the body of the HTTP response.
    ///
    /// - Throws: Socket.error if an error occurred while writing to the socket
    func end(text: String) throws {
        try write(from: text)
        try end()
    }
    
    /// Complete sending the HTTP response
    ///
    /// - Throws: Socket.error if an error occurred while writing to a socket
    func end() throws {
        if let data = frameData {
            http2Session.sendData(streamId: stream, data: data, headers: nghttp2Headers())
        }
    }
    
    /// Reset this response object back to it's initial state
    func reset() {
        statusCode = HTTPStatusCode.OK
        //headers.removeAll()
        headers["Date"] = [SPIUtils.httpDate()]
        headersStrings.removeAll()
    }
    
    private func nghttp2Headers() -> [nghttp2_nv] {
        var http2Headers = [nghttp2_nv]()
        let nvName: [UInt8] = Array(":status".utf8)
        headersStrings.append(nvName)
        let nvValue: [UInt8] = Array("\(statusCode?.rawValue ?? -1)".utf8)
        headersStrings.append(nvValue)
        http2Headers.append(nghttp2_nv(name: &headersStrings[0], value: &headersStrings[1], namelen: headersStrings[0].count, valuelen: headersStrings[1].count, flags: UInt8(NGHTTP2_NV_FLAG_NONE.rawValue)))
    
        var counter = 2
        for (_, header) in headers.enumerated() {
            if let firstValue = header.value.first {
                headersStrings.append(Array(header.key.utf8))
                headersStrings.append(Array(firstValue.utf8))
                http2Headers.append(nghttp2_nv(name: UnsafeMutablePointer(mutating: headersStrings[counter]), value: UnsafeMutablePointer(mutating: headersStrings[counter+1]), namelen: headersStrings[counter].count, valuelen: headersStrings[counter+1].count, flags: UInt8(NGHTTP2_NV_FLAG_NONE.rawValue)))
                counter += 2
            }
        }
        
        return http2Headers
    }
    
}
