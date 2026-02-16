// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Providers",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ProviderCatalog",
            targets: ["ProviderCatalog"]),
        .library(
            name: "CodexBarProviderCatalog",
            targets: ["CodexBarProviderCatalog"]),
        .library(
            name: "ProviderUsage",
            targets: ["ProviderUsage"]),
        .library(
            name: "NolonResourceKit",
            targets: ["NolonResourceKit"]),
        .library(
            name: "NolonCoreCLIKit",
            targets: ["NolonCoreCLIKit"]),
        // Unified library with all providers
        .library(
            name: "Providers",
            targets: ["Providers"]),
        // Individual provider libraries
        .library(
            name: "CodexProvider",
            targets: ["CodexProvider"]),
        .library(
            name: "CodexCLIKit",
            targets: ["CodexCLIKit"]),
        .library(
            name: "JsonRPCKit",
            targets: ["JsonRPCKit"]),
        .library(
            name: "CodexAppServerKit",
            targets: ["CodexAppServerKit"]),
        .library(
            name: "CopilotProvider",
            targets: ["CopilotProvider"]),
        .executable(
            name: "nolon",
            targets: ["NolonCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/linhay/SKProcessRunner", revision: "48c7918"),
        .package(url: "https://github.com/steipete/SweetCookieKit", from: "0.4.0"),
        .package(url: "https://github.com/mattt/swift-toml", from: "2.0.0"),
        .package(url: "https://github.com/linhay/STFilePath.git", from: "1.3.4"),
        .package(path: "../STJSON"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.2.1"),
    ],
    targets: [
        // Shared Provider utilities
        .target(
            name: "ProvidersShared",
            dependencies: [
                .product(name: "SKProcessRunner", package: "SKProcessRunner"),
                .product(name: "STFilePath", package: "STFilePath"),
            ],
            path: "Sources/Providers/Shared"
        ),

        // Codex Provider
        .target(
            name: "CodexCLIKit",
            dependencies: [
                "ProvidersShared",
                .product(name: "SKProcessRunner", package: "SKProcessRunner"),
                .product(name: "STFilePath", package: "STFilePath"),
            ],
            path: "Sources/CodexCLIKit"
        ),

        .target(
            name: "JsonRPCKit",
            dependencies: [
                .product(name: "SKProcessRunner", package: "SKProcessRunner"),
            ],
            path: "Sources/JsonRPCKit"
        ),

        .target(
            name: "CodexAppServerKit",
            dependencies: [
                "CodexCLIKit",
                "JsonRPCKit",
                .product(name: "STFilePath", package: "STFilePath"),
            ],
            path: "Sources/CodexAppServerKit"
        ),

        .target(
            name: "CodexProvider",
            dependencies: [
                "ProvidersShared",
                "CodexCLIKit",
                "CodexAppServerKit",
                .product(name: "SKProcessRunner", package: "SKProcessRunner"),
                "CodexBarProviderCatalog",
                .product(name: "SweetCookieKit", package: "SweetCookieKit"),
                .product(name: "TOML", package: "swift-toml"),
                .product(name: "STFilePath", package: "STFilePath"),
            ],
            path: "Sources/Providers/Codex"
        ),
        
        // Copilot Provider
        .target(
            name: "CopilotProvider",
            path: "Sources/Providers/Copilot"
        ),

        .target(
            name: "ProviderCatalog",
            dependencies: [
                .product(name: "SKProcessRunner", package: "SKProcessRunner"),
                .product(name: "STFilePath", package: "STFilePath"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/ProviderCatalog"
        ),

        .target(
            name: "CodexBarProviderCatalog",
            dependencies: [
                .product(name: "SweetCookieKit", package: "SweetCookieKit"),
            ],
            path: "Sources/CodexBarProviderCatalog"
        ),

        .target(
            name: "ProviderUsage",
            dependencies: [
                "ProvidersShared",
                "ProviderCatalog",
                "CodexBarProviderCatalog",
                "CodexProvider",
                "CopilotProvider",
                .product(name: "STJSON", package: "STJSON"),
                .product(name: "STFilePath", package: "STFilePath"),
            ],
            path: "Sources/ProviderUsage"
        ),

        .target(
            name: "NolonResourceKit",
            dependencies: [
                "ProvidersShared",
                "ProviderCatalog",
                .product(name: "SKProcessRunner", package: "SKProcessRunner"),
                .product(name: "STFilePath", package: "STFilePath"),
                .product(name: "STJSON", package: "STJSON"),
                .product(name: "TOML", package: "swift-toml"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/NolonResourceKit"
        ),

        .target(
            name: "NolonCoreCLIKit",
            dependencies: [
                "ProviderCatalog",
                "ProviderUsage",
                "CodexProvider",
                "CodexCLIKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SKProcessRunner", package: "SKProcessRunner"),
                .product(name: "STFilePath", package: "STFilePath"),
            ],
            path: "Sources/NolonCoreCLIKit"
        ),

        .executableTarget(
            name: "NolonCLI",
            dependencies: ["NolonCoreCLIKit"],
            path: "Sources/NolonCLI"
        ),

        // Unified Providers module (re-exports both)
        .target(
            name: "Providers",
            dependencies: ["CodexProvider", "CopilotProvider", "ProviderCatalog", "CodexBarProviderCatalog", "ProviderUsage"],
            path: "Sources/Providers",
            exclude: ["Codex", "Copilot", "Shared"],
            sources: ["Providers.swift"]
        ),
        
        // Tests
        .testTarget(
            name: "ProvidersTests",
            dependencies: [
                "Providers",
                "ProviderCatalog",
                "CodexBarProviderCatalog",
                "ProviderUsage",
                "CodexProvider",
                "CopilotProvider",
                "NolonCoreCLIKit",
                "NolonResourceKit",
                .product(name: "STFilePath", package: "STFilePath"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]
        ),
    ]
)
