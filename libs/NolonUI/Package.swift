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
        .package(path: "../Providers"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.1"),
        .package(url: "https://github.com/linhay/STFilePath.git", from: "1.3.4")
    ],
    targets: [
        .target(
            name: "NolonUI",
            dependencies: [
                .product(name: "NolonUIFoundation", package: "NolonUIFoundation"),
                .product(name: "ProviderCatalog", package: "Providers"),
                .product(name: "NolonResourceKit", package: "Providers"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "STFilePath", package: "STFilePath")
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
