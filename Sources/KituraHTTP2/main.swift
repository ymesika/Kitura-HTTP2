import Kitura

// Create a new router
let router = Router()
HTTP2.using(serverDelegate: router)

// Handle HTTP GET requests to /
router.get("/") {
    request, response, next in
    response.headers.setType("html")
    response.send("<html><head><title>Success</title></head><body><h1>Yay, It Worked!!</h1></body><//html>")
    next()
}

router.get("/text") {
    request, response, next in
    response.headers.setType("text")
    response.send("Sample plain text body")
    next()
}

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8080, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
