// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NolonUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NolonUI",
            targets: ["NolonUI"]
        )
    ],
    dependencies: [
        .package(path: "../NolonUIFoundation")
    ],
    targets: [
        .target(
            name: "NolonUI",
            dependencies: [
                .product(name: "NolonUIFoundation", package: "NolonUIFoundation")
            ]
        ),
        .testTarget(
            name: "NolonUITests",
            dependencies: [
                "NolonUI",
                .product(name: "NolonUIFoundation", package: "NolonUIFoundation")
            ]
        )
    ]
)
