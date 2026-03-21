// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NolonUIFoundation",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NolonUIFoundation",
            targets: ["NolonUIFoundation"]
        )
    ],
    targets: [
        .target(
            name: "NolonUIFoundation"
        ),
        .testTarget(
            name: "NolonUIFoundationTests",
            dependencies: ["NolonUIFoundation"]
        )
    ]
)
