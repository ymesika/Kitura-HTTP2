import Kitura

// Create a new router
let router = Router()
let http2 = HTTP2()

// Handle HTTP GET requests to /
router.get("/") {
    request, response, next in
    response.send("Hello, World!\n")
    next()
}

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
