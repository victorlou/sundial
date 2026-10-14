// swift-tools-version: 6.2
import PackageDescription

// SwiftUI views and @Observable models (architecture §3). Imports Domain, never Data.
let package = Package(
    name: "Features",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Features", targets: ["Features"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
    ],
    targets: [
        .target(name: "Features", dependencies: ["Domain"]),
    ]
)
