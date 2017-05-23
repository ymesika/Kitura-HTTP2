import PackageDescription

let package = Package(
    name: "Kitura-HTTP2",
    targets: [
        Target(name: "KituraHTTP2", dependencies: ["nghttp2"]),
        Target(name: "nghttp2", dependencies: [])
    ],
    dependencies: [
        .Package(url: "https://github.com/ymesika/Kitura-net.git", majorVersion: 1, minor: 7),
        .Package(url: "https://github.com/ymesika/Kitura.git", majorVersion: 1, minor: 7),
        .Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1, minor: 7)
    ]
)
