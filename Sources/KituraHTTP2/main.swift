import Kitura

// Create a new router
let router = Router()

// Enable HTTP/2
HTTP2.using(serverDelegate: router)

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8080, with: router)


// HTTP/2 over secured connection is only support on Linux environment.
// Modern browsers support HTTP/2 only over secured connection.
#if os(Linux)

let myCertPath = "path to certificate.pem"
let myKeyPath = "path to key.pem"
	
let mySSLConfig = SSLConfig(withCACertificateDirectory: nil, usingCertificateFile: myCertPath, withKeyFile: myKeyPath, usingSelfSignedCerts: true, cipherSuite: "ALL")
	
Kitura.addHTTPServer(onPort: 8443, with: router, withSSL: mySSLConfig)

#endif


// Start the Kitura runloop (this call never returns)
Kitura.run()
