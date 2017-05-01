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
import nghttp2

struct SessionInfo {
    weak var handler: IncomingSocketHandler? = nil
    var session: UnsafeMutablePointer<nghttp2_session>? = nil
    weak var processor: H2CSocketProcessor? = nil
    var streamsData = [Int32: StreamData]()
    
    public mutating func streamClosed(streamId: Int32) {
        streamsData[streamId] = nil
    }
}

struct StreamData {
    var streamId: Int32
    var dataLengths: [UnsafeMutableRawPointer: Int]
}

class H2CSocketProcessor: IncomingSocketProcessor {
    
    /// The socket if idle will be kept alive until...
    public var keepAliveUntil: TimeInterval = 500.0
    
    /// A flag to indicate that the socket has a request in progress
    public var inProgress = true
    
    private var sessionInfo: SessionInfo?
    
    public weak var handler: IncomingSocketHandler? {
        didSet {
            if let handler = handler {
                sessionInfo?.handler = handler
                
                if (sendSettings() != 0) {
                    print("Failed to send upgrade response header")
                }
                
                var data: [UInt8] = Array("<html><head><title>Success</title></head><body><h1>It Worked!</h1></body><//html>".utf8)
                let _ = sendData(streamId: 1, data: &data, length: data.count)
            }
        }
    }
    
    public init(settingsPayload: Data, handler: IncomingSocketHandler) {
        sessionInfo = SessionInfo()
        sessionInfo?.handler = handler
        sessionInfo?.processor = self
        sessionInfo?.session = initHttp2Session()
        
        nghttp2_session_upgrade2(sessionInfo?.session, [UInt8](settingsPayload), settingsPayload.count, 0, nil)
    }
    
    /// Process data read from the socket.
    ///
    /// - Parameter buffer: An NSData object containing the data that was read in
    ///                    and needs to be processed.
    ///
    /// - Returns: true if the data was processed, false if it needs to be processed later.
    public func process(_ buffer: NSData) -> Bool {
        if sessionReceive(buffer: buffer) != 0 {
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
        nghttp2_session_del(sessionInfo?.session)
        print("HTTP2 session closed")
        handler?.prepareToClose()
    }
    
    /// Called by the `IncomingSocketHandler` to tell us that the socket has been closed.
    public func socketClosed() {
        print("Socket closed")
    }
    
    private func initHttp2Session() -> UnsafeMutablePointer<nghttp2_session>? {
        var callbacks_ = nghttp2_session_callbacks()
        var callbacks: UnsafeMutablePointer<nghttp2_session_callbacks>? = UnsafeMutablePointer<nghttp2_session_callbacks>(&callbacks_)
        var stat = nghttp2_session_callbacks_new(UnsafeMutablePointer<UnsafeMutablePointer<nghttp2_session_callbacks>?>(&callbacks))
        guard stat == 0 else {
            print("Failed to initialize the callbacks struct with error: \(stat)")
            return nil
        }
        
        
        let sendCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, UnsafePointer<UInt8>?, Int, Int32, UnsafeMutableRawPointer?) -> Int = { (session, data, length, flags, userData) in
            if let userData = userData, let handler = userData.load(as: SessionInfo.self).handler {
                if let data = data, length > 0 {
                    handler.write(from: data, length: length)
                }
            }
            return length
        }
        nghttp2_session_callbacks_set_send_callback(callbacks, sendCallback)
        
        
        let onFrameRecvCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, UnsafePointer<nghttp2_frame>?, UnsafeMutableRawPointer?) -> Int32 = { (session, frame, userData) in
            if let frame = frame {
                switch (UInt32(frame.pointee.hd.type)) {
                case NGHTTP2_DATA.rawValue:
                    print("Data")
                    fallthrough
                case NGHTTP2_HEADERS.rawValue:
                    print("Headers")
                    /* Check that the client request has finished */
                    if (frame.pointee.hd.flags & UInt8(NGHTTP2_FLAG_END_HEADERS.rawValue)) != 0 {
                        if let userData = userData, let session = userData.load(as: SessionInfo.self).session {
                            let streamData = nghttp2_session_get_stream_user_data(session, frame.pointee.hd.stream_id)
                            /* For DATA and HEADERS frame, this callback may be called after
                             on_stream_close_callback. Check that stream still alive. */
                            if streamData == nil {
                                return 0
                            }
                            //TODO: Process the request
                        }
                    }
                case NGHTTP2_SETTINGS.rawValue:
                    print("Settings")
                case NGHTTP2_PRIORITY.rawValue:
                    print("Priority")
                case NGHTTP2_GOAWAY.rawValue:
                    print("Goaway")
                default:
                    print("Unknown - type:\(frame.pointee.hd.type) streamId:\(frame.pointee.hd.stream_id)")
                }
            }
            return 0
        }
        nghttp2_session_callbacks_set_on_frame_recv_callback(callbacks, onFrameRecvCallback)
        
        
        let onStreamCloseCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, Int32, UInt32, UnsafeMutableRawPointer?) -> Int32 = { (session, streamId, errorCode, userData) in
            Log.debug("Stream \(streamId) closed")
            return 0
        }
        nghttp2_session_callbacks_set_on_stream_close_callback(callbacks, onStreamCloseCallback)
        
        
        let onHeaderCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, UnsafePointer<nghttp2_frame>?, UnsafePointer<UInt8>?, Int, UnsafePointer<UInt8>?, Int, UInt8, UnsafeMutableRawPointer?) -> Int32 = { (session, frame, name, namelen, value, valuelen, flags, userData) in
            return 0
        }
        nghttp2_session_callbacks_set_on_header_callback(callbacks, onHeaderCallback)
        
        
        let onBeginHeadersCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, UnsafePointer<nghttp2_frame>?, UnsafeMutableRawPointer?) -> Int32 = { (session, frame, userData) in
            
            guard let frame = frame else {
                return -1
            }
            
            if (frame.pointee.hd.type != UInt8(NGHTTP2_HEADERS.rawValue) ||
                frame.pointee.headers.cat != NGHTTP2_HCAT_REQUEST) {
                return 0
            }
            
            //TODO Create stream user data object and attach it to the stream by calling:
            var streamInfo = ""
            nghttp2_session_set_stream_user_data(session, frame.pointee.hd.stream_id, &streamInfo)
            
            return 0
        }
        nghttp2_session_callbacks_set_on_begin_headers_callback(callbacks, onBeginHeadersCallback)
        
        
        var session: UnsafeMutablePointer<nghttp2_session>?
        stat = nghttp2_session_server_new(UnsafeMutablePointer<UnsafeMutablePointer<nghttp2_session>?>(&session), callbacks, &sessionInfo)
        guard stat == 0 else {
            print("Failed to initialize the callbacks struct with error: \(stat)")
            return nil
        }
        
        nghttp2_session_callbacks_del(callbacks)
        
        return session
    }
    
    private func sendSettings() -> Int32 {
        let iv: [nghttp2_settings_entry] = [
            nghttp2_settings_entry(settings_id: Int32(NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS.rawValue), value: 100)
        ]
        let result = nghttp2_submit_settings(sessionInfo?.session, UInt8(NGHTTP2_FLAG_NONE.rawValue), iv, iv.count)
        if (result != 0) {
            print("Failed to submit settings")
            return result
        }
        
        return sessionSend()
    }
    
    private func sendData(streamId: Int32, data: UnsafeMutableRawPointer, length: Int) -> Int32 {
        var nvName: [UInt8] = Array(":status".utf8)
        var nvValue: [UInt8] = Array("200".utf8)
        let headers: [nghttp2_nv] = [ nghttp2_nv(name: &nvName, value: &nvValue, namelen: nvName.count, valuelen: nvValue.count, flags: UInt8(NGHTTP2_NV_FLAG_NONE.rawValue)) ]
        
        let dataSource = nghttp2_data_source(ptr: data)
        let readCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, Int32, UnsafeMutablePointer<UInt8>?, Int, UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<nghttp2_data_source>?, UnsafeMutableRawPointer?) -> Int = { (session, streamId, buf, length, dataFlags, source, userData) in
            guard let source = source else {
                return -1
            }
            
            guard let userData = userData, let streamInfo = userData.load(as: SessionInfo.self).streamsData[streamId] else {
                return -1
            }
            
            let opaquePtr = OpaquePointer(source.pointee.ptr)
            
            guard let dataPtr = UnsafeMutablePointer<UInt8>(opaquePtr), let toBuffer = buf, let dataLength = streamInfo.dataLengths[dataPtr] else {
                return -1
            }
            
            toBuffer.initialize(from: dataPtr, count: dataLength)
            dataFlags?.pointee |= NGHTTP2_DATA_FLAG_EOF.rawValue
            return dataLength
        }
        var dataProvider = nghttp2_data_provider(source: dataSource, read_callback: readCallback)
        
        var streamData = StreamData(streamId: streamId, dataLengths: [UnsafeMutableRawPointer: Int]())
        streamData.dataLengths[data] = length
        sessionInfo?.streamsData[streamId] = streamData
        
        let rv = nghttp2_submit_response(sessionInfo?.session, streamId, headers, headers.count, &dataProvider)
        if rv != 0 {
            return -1
        }
        
        return sessionSend()
    }
    
    /* Read the data in the buffer and feed it into nghttp2 library function. Invocation of nghttp2_session_mem_recv() may make
     additional pending frames, so call session_send() at the end of the function. */
    private func sessionReceive(buffer: NSData) -> Int32 {
        let readlen = nghttp2_session_mem_recv(sessionInfo?.session, buffer.bytes.assumingMemoryBound(to: UInt8.self), buffer.length)
        if readlen < 0 {
            return -1
        }
        return sessionSend()
    }
    
    private func sessionSend() -> Int32 {
        let result = nghttp2_session_send(sessionInfo?.session)
        if result != 0 {
            return -1
        }
        return 0
    }
    
}
