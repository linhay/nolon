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
        .package(path: "../NolonUIFoundation"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.1")
    ],
    targets: [
        .target(
            name: "NolonUI",
            dependencies: [
                .product(name: "NolonUIFoundation", package: "NolonUIFoundation"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
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
