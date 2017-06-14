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
import LoggerAPI
import Socket

class HTTP2SocketProcessor: IncomingSocketProcessor {
    
    /// The socket if idle will be kept alive until...
    public var keepAliveUntil: TimeInterval = 500.0
    
    /// A flag to indicate that the socket has a request in progress
    public var inProgress = true
	
	/// The handler of this processor
    public weak var handler: IncomingSocketHandler? {
        didSet{
            if handler != nil {
                // Send HTTP/2 client connection header, which includes 24 bytes
                // magic octets and SETTINGS frame
				do {
					try http2Session?.sendServerConnectionHeader()
				} catch {
					Log.error("Failed to send server connection response header")
				}
				
				// If it is a connection upgrade, send the response data to the initial
				// request
                if http1Upgrade {
                    http2Session?.sendInitialRequestData()
                }
            }
        }
    }
	
	/// Instance of 'HTTP2Session' to handle http2 operations
    private let http2Session: HTTP2Session?
	
	/// Indicates whether this connection is a result of HTTP/1 connection upgrade
    private let http1Upgrade: Bool
	
	/// Create an instance of 'IncomingSocketProcessor'
	///
	/// - Parameter session: Instance of 'HTTP2Session'
	/// - Parameter upgrade: Was it an HTTP/1 connection upgrade request?
    public init(session: HTTP2Session, upgrade: Bool) {
        http2Session = session
        http1Upgrade = upgrade
    }
    
    /// Process data read from the socket.
    ///
    /// - Parameter buffer: An NSData object containing the data that was read in
    ///                    and needs to be processed.
    ///
    /// - Returns: true if the data was processed, false if it needs to be processed later.
    public func process(_ buffer: NSData) -> Bool {
        if http2Session?.processIncomingData(buffer: buffer) != 0 {
            Log.error("Failed to proccess incoming socket data")
            return false
        }
        return true
    }
    
    /// Write data to the socket
    ///
    /// - Parameter from: An NSData object containing the bytes to be written to the socket.
    public func write(from data: NSData) {
        Log.debug("Writing \(data.length) bytes")
        handler?.write(from: data)
    }
    
    /// Write a sequence of bytes in an array to the socket
    ///
    /// - Parameter from: An UnsafeRawPointer to the sequence of bytes to be written to the socket.
    /// - Parameter length: The number of bytes to write to the socket.
    public func write(from bytes: UnsafeRawPointer, length: Int) {
        Log.debug("Writing \(length) bytes")
        handler?.write(from: bytes, length: length)
    }
    
    /// Close the socket and mark this handler as no longer in progress.
    public func close() {
        http2Session?.close()
        handler?.prepareToClose()
    }
    
    /// Called by the `IncomingSocketHandler` to tell us that the socket has been closed.
    public func socketClosed() {
        Log.debug("Socket closed")
    }
    
}

class HTTP2SocketProcessorCreator: IncomingSocketProcessorCreator {
    public let name = "h2"
    
    public func createIncomingSocketProcessor(socket: Socket, using: ServerDelegate) -> IncomingSocketProcessor {
        Log.debug("Creating IncomingSocketProcessor for socket \(socket.socketfd). Remote address: \(socket.remoteHostname)")
        let session = HTTP2Session()
        session.remoteAddress = socket.remoteHostname
        let processor = HTTP2SocketProcessor(session: session, upgrade: false)
        session.processor = processor
        return processor
    }
}

