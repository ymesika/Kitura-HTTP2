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


public class H2ConnectionUpgradeFactory: ConnectionUpgradeFactory {
    
    /// The name of the protocol supported by this `ConnectionUpgradeFactory`.
    public let name = "h2c"
    
    init() {
        ConnectionUpgrader.register(factory: self)
    }
    
    public func upgrade(handler: IncomingSocketHandler, request: ServerRequest, response: ServerResponse) -> (IncomingSocketProcessor?, String?) {
        
        guard let settings = request.headers["HTTP2-Settings"] else {
            return (nil, "Upgrade request MUST include exactly one 'HTTP2-Settings' header field.")
        }
        
        guard settings.count == 1 else {
            return (nil, "Upgrade request MUST include exactly one 'HTTP2-Settings' header field.")
        }
        
        guard let decodedSettings =  Data(base64Encoded: HTTP2Utils.base64urlToBase64(base64url: settings[0])) else {
            return (nil, "Value for 'HTTP2-Settings' is not Base64 URL encoded")
        }
        
        response.statusCode = .switchingProtocols
        
        let session = Http2Session(settingsPayload: decodedSettings, with: request)
        let processor = H2CSocketProcessor(session: session, upgrade: true)
        session.processor = processor
        
        return (processor, nil)
    }
}
