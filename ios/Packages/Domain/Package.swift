// swift-tools-version: 6.2
import PackageDescription

// Pure Swift, no dependencies (architecture §3).
let package = Package(
    name: "Domain",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
    ],
    targets: [
        .target(name: "Domain"),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
    ]
)
