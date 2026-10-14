// swift-tools-version: 6.2
import PackageDescription

// PowerSync, Supabase, and repository implementations (architecture §3). Imports Domain, never Features.
let package = Package(
    name: "Data",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Data", targets: ["Data"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
    ],
    targets: [
        .target(name: "Data", dependencies: ["Domain"]),
    ]
)
