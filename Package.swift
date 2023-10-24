// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "es-cast-client-ios",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "es-cast-client-ios",
            targets: ["es-cast-client-ios"]),
    ],
    targets: [
        .target(
            name: "es-cast-client-ios",
        dependencies: ["Proxy"]),
        .testTarget(
            name: "es-cast-client-iosTests",
            dependencies: ["es-cast-client-ios"]),
        .binaryTarget(name: "Proxy", path: "./Porxy.xcframework"),
    ])
