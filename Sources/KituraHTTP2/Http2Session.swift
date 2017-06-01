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
import nghttp2
import LoggerAPI
import KituraNet

/// This struct holds metadata for a specific stream and its data.
/// Most of the information is coming from the header frame once the stream
/// has been created.
/// The dataInfo holds mapping between data to be sent and its total length and
/// the offset for the next data frame. This is being used for breaking large data
/// into pieces and send it in multiple data frames.
struct StreamData {
	
	// The unique stream ID
    var streamId: Int32
	
	// Mapping from data pointer to the length of data and offset for next submission
	var dataInfo = [UnsafeMutableRawPointer: (length: Int, offset: Int)]()
	
	// Request headers
    var headers = HeadersContainer()
	
	// The URL path of the request
    var requestPath: String?
	
	// The HTTP method of the request
    var method: String?
	
	// HTTP scheme used in the request
    var scheme: String?
	
	// The request authority
    var authority: String?
	
	// Initialize new instance for the specified stream ID
    init(streamId: Int32) {
        self.streamId = streamId
    }
}

class Http2Session {
	
	// Reference to the processor that created this session
    weak var processor: H2CSocketProcessor? = nil
	
	// The initial request (when initiated by an upgrade request)
	var initialRequest: HTTP2ServerRequest?
	
	// The nghttp2 session
	var session: UnsafeMutablePointer<nghttp2_session>? = nil
	
	// Mapping between streams IDs and the information about data waiting to be sent
	var streamsData = [Int32: StreamData]()
	
	// The user data object to be used in all nghttp2 callback functions
	var nghttp2UserData: Http2Session?
	
	// Holds the hostname address of the client. Being set externally
    var remoteAddress: String?
	
	/// Initialize an `Http2Session` instance
	/// This initializer is being used when the negotiated ALPN protocol over SSL is 'h2'. Meaning the client
	/// requested that the protocol to use is the HTTP/2.
    init() {
        nghttp2UserData = self
        session = initNGHttp2Session()
    }
	
	/// Initialize an `Http2Session` instance
	/// This initializer is being used when an HTTP upgrade request is asking for an upgrade to HTTP/2 using
	/// the 'h2c' upgrade name over non secured connection.
	///
	/// - Parameter settingsPayload: The initial settings payload that was sent in the upgrade request.
	/// - Parameter serverRequest: The request that initiated the upgrade
    init(settingsPayload: Data, with serverRequest: ServerRequest? = nil) {
        nghttp2UserData = self
        session = initNGHttp2Session()
        
        if let serverRequest = serverRequest {
            initialRequest = HTTP2ServerRequest(request: serverRequest)
        }
        
        nghttp2_session_upgrade2(session, [UInt8](settingsPayload), settingsPayload.count, 0, nil)
    }
	
	/// The function will send a response to the initial request. Only used when connection upgrade has
	/// initiated the session.
	/// It can be called once the handler has been set and ready to handle requests.
    public func sendInitialRequestData() {
        if let request = initialRequest {
            //Data frame for an upgrade request will be returned on stream 1
            let response = HTTP2ServerResponse(session: self, streamId: 1)
            HTTP2.delegate?.handle(request: request, response: response)
        }
    }
	
	/// Close this session.
    public func close() {
		nghttp2_session_del(session)
		session = nil
		processor = nil
		nghttp2UserData = nil
        Log.debug("HTTP2 session closed")
    }
	
	/// Initialize a new nghttp2 session and return it.
    private func initNGHttp2Session() -> UnsafeMutablePointer<nghttp2_session>? {
        var callbacks_ = nghttp2_session_callbacks()
        var callbacks: UnsafeMutablePointer<nghttp2_session_callbacks>? = UnsafeMutablePointer<nghttp2_session_callbacks>(&callbacks_)
        var stat = nghttp2_session_callbacks_new(UnsafeMutablePointer<UnsafeMutablePointer<nghttp2_session_callbacks>?>(&callbacks))
        guard stat == 0 else {
            Log.error("Failed to initialize the callbacks struct with error: \(stat)")
            return nil
        }
        
        
        let sendCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, UnsafePointer<UInt8>?, Int, Int32, UnsafeMutableRawPointer?) -> Int = { (session, data, length, flags, userData) in
            if let userData = userData, let processor = userData.load(as: Http2Session.self).processor {
                if let data = data, length > 0 {
                    processor.write(from: data, length: length)
                }
            }
            return length
        }
        nghttp2_session_callbacks_set_send_callback(callbacks, sendCallback)
        
        
        let onFrameRecvCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, UnsafePointer<nghttp2_frame>?, UnsafeMutableRawPointer?) -> Int32 = { (session, frame, userData) in
            if let frame = frame {
                switch (UInt32(frame.pointee.hd.type)) {
                case NGHTTP2_DATA.rawValue:
                    Log.debug("Received Frame - Data")
                    fallthrough
                case NGHTTP2_HEADERS.rawValue:
                    Log.debug("Received Frame - Headers")
                    /* Check that the client request has finished */
                    if (frame.pointee.hd.flags & UInt8(NGHTTP2_FLAG_END_HEADERS.rawValue)) != 0 {
                        if let userData = userData {
                            /* For DATA and HEADERS frame, this callback may be called after
                             on_stream_close_callback. Check that stream still alive. */
                            if nghttp2_session_get_stream_user_data(userData.load(as: Http2Session.self).session, frame.pointee.hd.stream_id) == nil {
                                return 0
                            }
                            
                            let session = userData.load(as: Http2Session.self)
                            let streamId = frame.pointee.hd.stream_id
                            if let sData = session.streamsData[streamId], let requestPath = sData.requestPath, let urlFromPath = URL(string: requestPath), let pathData = requestPath.data(using: .utf8) {
								let request = HTTP2ServerRequest(url: pathData, urlURL: urlFromPath, remoteAddress: session.remoteAddress ?? "")
								request.method = sData.method ?? "GET"
								for (key, value) in sData.headers {
									request.headers.append(key, value: value)
								}
								let response = HTTP2ServerResponse(session: session, streamId: streamId)
								HTTP2.delegate?.handle(request: request, response: response)
                            }
                        }
                    }
				case NGHTTP2_PING.rawValue:
					Log.debug("Received Frame - Ping (automatically handled by the nghttp2 library)")
                case NGHTTP2_SETTINGS.rawValue:
                    Log.debug("Received Frame - Settings")
                case NGHTTP2_WINDOW_UPDATE.rawValue:
                    Log.debug("Received Frame - Window Update")
                case NGHTTP2_PRIORITY.rawValue:
                    Log.debug("Received Frame - Priority")
                case NGHTTP2_RST_STREAM.rawValue:
                    Log.debug("Received Frame - Rst Stream (id: \(frame.pointee.hd.stream_id))")
                case NGHTTP2_GOAWAY.rawValue:
                    Log.debug("Received Frame - Goaway")
                default:
                    Log.warning("Received Unknown Frame - type:\(frame.pointee.hd.type) streamId:\(frame.pointee.hd.stream_id)")
                }
            }
            return 0
        }
        nghttp2_session_callbacks_set_on_frame_recv_callback(callbacks, onFrameRecvCallback)
        
        
        let onStreamCloseCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, Int32, UInt32, UnsafeMutableRawPointer?) -> Int32 = { (session, streamId, errorCode, userData) in
            Log.debug("Stream \(streamId) closed")
			userData?.load(as: Http2Session.self).streamsData[streamId] = nil
            return 0
        }
        nghttp2_session_callbacks_set_on_stream_close_callback(callbacks, onStreamCloseCallback)
        
        
        
        let onHeaderCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, UnsafePointer<nghttp2_frame>?, UnsafePointer<UInt8>?, Int, UnsafePointer<UInt8>?, Int, UInt8, UnsafeMutableRawPointer?) -> Int32 = { (session, frame, name, namelen, value, valuelen, flags, userData) in
            // Called when nghttp2 library emits single header name/value pair.
            
            if let frame = frame {
                switch frame.pointee.hd.type {
                case UInt8(NGHTTP2_HEADERS.rawValue):
                    if (frame.pointee.headers.cat != NGHTTP2_HCAT_REQUEST) {
                        break
                    }
                    
                    if let name = name, let value = value, let userData = userData {
                        let nameData = Data(bytes: name, count: namelen)
                        let nameStr = String(data: nameData, encoding: .utf8)
                        
                        let valueData = Data(bytes: value, count: valuelen)
                        let valueStr = String(data: valueData, encoding: .utf8)
                        
                        let streamId = frame.pointee.hd.stream_id
                        
                        if let nameStr = nameStr, let valueStr = valueStr {
                            Log.debug("Received a header - name: \(nameStr), value: \(valueStr)")
                            
                            let session = userData.load(as: Http2Session.self)
                            var streamData = session.streamsData[streamId]
                            
                            switch nameStr {
                            case ":path": streamData?.requestPath = valueStr
                            case ":method": streamData?.method = valueStr
                            case ":scheme": streamData?.scheme = valueStr
                            case ":authority": streamData?.authority = valueStr
                            default: streamData?.headers.append(nameStr, value: valueStr)
                            }
                            
                            session.streamsData[streamId] = streamData
                        }
                    }
                    
                default:
                    break
                }
            }
            
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
            
            
            if let userData = userData {
                let streamId = frame.pointee.hd.stream_id
                var streamData = StreamData(streamId: streamId)
                userData.load(as: Http2Session.self).streamsData[streamId] = streamData
                nghttp2_session_set_stream_user_data(session, streamId, &streamData)
                
                Log.debug("Stream \(streamId) was created")
            }
            
            return 0
        }
        nghttp2_session_callbacks_set_on_begin_headers_callback(callbacks, onBeginHeadersCallback)
        
        
        var session: UnsafeMutablePointer<nghttp2_session>?
        stat = nghttp2_session_server_new(UnsafeMutablePointer<UnsafeMutablePointer<nghttp2_session>?>(&session), callbacks, &nghttp2UserData)
        guard stat == 0 else {
            Log.error("Failed to initialize the callbacks struct with error: \(stat)")
            return nil
        }
        
        nghttp2_session_callbacks_del(callbacks)
        
        return session
    }
	
	/// The function will send HTTP/2 client connection header, which includes 24 bytes	magic octets and SETTINGS frame
	public func sendServerConnectionHeader() throws {
        let iv: [nghttp2_settings_entry] = [
            nghttp2_settings_entry(settings_id: Int32(NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS.rawValue), value: 100)
        ]
        var rv = nghttp2_submit_settings(session, UInt8(NGHTTP2_FLAG_NONE.rawValue), iv, iv.count)
        if rv != 0 {
            Log.error("Failed to submit settings")
            throw HTTP2Errors.failedToSend
        }
		
		rv = sessionSend()
		if rv != 0 {
			Log.error("Failed to send session")
			throw HTTP2Errors.failedToSend
		}
    }
    
	/// The function will use the nghttp2 library to send stream data to the client.
	///
	/// - Parameter streamId: The ID of the stream to be used in sent frame(s)
	/// - Parameter data: The Data object that holds the data to be sent
	/// - Parameter headers: A collection of name-value headers to be added to the data frame
	public func sendData(streamId: Int32, data: Data, headers: [nghttp2_nv]) throws {
        var mutData: [UInt8] = Array(data)
		if sendData(streamId: streamId, data: &mutData, length: mutData.count, headers: headers) != 0 {
			throw HTTP2Errors.failedToSend
		}
    }
	
	/// The function will use the nghttp2 library to send stream data to the client.
	///
	/// - Parameter streamId: The ID of the stream to be used in sent frame(s)
	/// - Parameter data: A pointer to the data bytes
	/// - Parameter length: The number of bytes of data
	/// - Parameter headers: A collection of name-value headers to be added to the data frame
	/// - Returns: 0 if successfully sent. Other value if error occurred.
    private func sendData(streamId: Int32, data: UnsafeMutableRawPointer, length: Int, headers: [nghttp2_nv]) -> Int32 {
        let dataSource = nghttp2_data_source(ptr: data)
        let readCallback: @convention(c) (UnsafeMutablePointer<nghttp2_session>?, Int32, UnsafeMutablePointer<UInt8>?, Int, UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<nghttp2_data_source>?, UnsafeMutableRawPointer?) -> Int = { (session, streamId, buf, length, dataFlags, source, userData) in
            guard let source = source else {
                return -1
            }
            
            guard let userData = userData, let streamInfo = userData.load(as: Http2Session.self).streamsData[streamId] else {
                return -1
            }
            
            let opaquePtr = OpaquePointer(source.pointee.ptr)
            
            guard let dataPtr = UnsafeMutablePointer<UInt8>(opaquePtr), let toBuffer = buf, let dataInfo = streamInfo.dataInfo[dataPtr] else {
                return -1
            }
			let dataLengthRemained = dataInfo.length - dataInfo.offset
			let copyLength = min(dataLengthRemained, length)
            toBuffer.initialize(from: dataPtr.advanced(by: dataInfo.offset), count: copyLength)
			if copyLength == dataLengthRemained {
				//No more data left
				dataFlags?.pointee |= NGHTTP2_DATA_FLAG_EOF.rawValue
			} else {
				//The data left is larger than the max payload length
				let offset = dataInfo.offset + copyLength
				userData.load(as: Http2Session.self).streamsData[streamId]?.dataInfo[dataPtr] = (dataInfo.length, offset)
			}
            return copyLength
        }
        var dataProvider = nghttp2_data_provider(source: dataSource, read_callback: readCallback)
        
        var streamData = StreamData(streamId: streamId)
        streamData.dataInfo[data] = (length, 0)
        streamsData[streamId] = streamData
		
        let rv = nghttp2_submit_response(session, streamId, headers, headers.count, &dataProvider)
        if rv != 0 {
            return -1
        }
        
        return sessionSend()
    }
    
    /// Read the data in the buffer and feed it into nghttp2 library function. Invocation of nghttp2_session_mem_recv() may make
    /// additional pending frames, so call session_send() at the end of the function.
    public func processIncomingData(buffer: NSData) -> Int32 {
        let readlen = nghttp2_session_mem_recv(session, buffer.bytes.assumingMemoryBound(to: UInt8.self), buffer.length)
        if readlen < 0 {
            return -1
        }
        return sessionSend()
    }
	
	/// Send all the session data that is waiting to be sent (all streams)
    private func sessionSend() -> Int32 {
        let result = nghttp2_session_send(session)
        if result != 0 {
            return -1
        }
        return 0
    }
    
}
