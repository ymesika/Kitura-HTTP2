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

import KituraNet

//
// Exceptions
//
enum HTTP2Errors : Swift.Error {
	case failedToSend
	case internalError
}

/// Main class for the Kitura-HTTP2 API.
public class HTTP2 {
    static var delegate: ServerDelegate?
    
    public static func using(serverDelegate: ServerDelegate?) {
        HTTP2.delegate = serverDelegate
        _ = HTTP2ConnectionUpgradeFactory()
        
        HTTPServer.register(incomingSocketProcessorCreator: HTTP2SocketProcessorCreator())
    }
}
