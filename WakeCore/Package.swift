// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WakeCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "WakeCore", targets: ["WakeCore"]),
    ],
    targets: [
        .target(name: "WakeCore"),
    ]
)
