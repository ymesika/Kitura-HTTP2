/*
 * Copyright IBM Corporation 2016-2017
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
import LoggerAPI

class H2CSocketProcessor: IncomingSocketProcessor {
    
    /// The socket if idle will be kept alive until...
    public var keepAliveUntil: TimeInterval = 500.0
    
    /// A flag to indicate that the socket has a request in progress
    public var inProgress = true
    
    public weak var handler: IncomingSocketHandler? {
        didSet{
            http2Session?.sendInitialFrames()
        }
    }
    
    private let http2Session: Http2Session?
    
    public init(session: Http2Session) {
        http2Session = session
    }
    
    /// Process data read from the socket.
    ///
    /// - Parameter buffer: An NSData object containing the data that was read in
    ///                    and needs to be processed.
    ///
    /// - Returns: true if the data was processed, false if it needs to be processed later.
    public func process(_ buffer: NSData) -> Bool {
        if http2Session?.processIncomingData(buffer: buffer) != 0 {
            print("Failed to proccess incoming socket data")
            return false
        }
        return true
    }
    
    /// Write data to the socket
    ///
    /// - Parameter from: An NSData object containing the bytes to be written to the socket.
    public func write(from data: NSData) {
        handler?.write(from: data)
    }
    
    /// Write a sequence of bytes in an array to the socket
    ///
    /// - Parameter from: An UnsafeRawPointer to the sequence of bytes to be written to the socket.
    /// - Parameter length: The number of bytes to write to the socket.
    public func write(from bytes: UnsafeRawPointer, length: Int) {
        handler?.write(from: bytes, length: length)
    }
    
    /// Close the socket and mark this handler as no longer in progress.
    public func close() {
        http2Session?.close()
        handler?.prepareToClose()
    }
    
    /// Called by the `IncomingSocketHandler` to tell us that the socket has been closed.
    public func socketClosed() {
        print("Socket closed")
    }
    
}
