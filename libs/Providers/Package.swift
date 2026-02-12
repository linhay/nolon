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
    ],
    dependencies: [
        .package(url: "https://github.com/linhay/SKProcessRunner", from: "0.0.5"),
        .package(url: "https://github.com/steipete/SweetCookieKit", from: "0.4.0"),
        .package(url: "https://github.com/mattt/swift-toml", from: "2.0.0"),
    ],
    targets: [
        // Shared Provider utilities
        .target(
            name: "ProvidersShared",
            path: "Sources/Providers/Shared"
        ),

        // Codex Provider
        .target(
            name: "CodexCLIKit",
            dependencies: [
                "ProvidersShared",
                .product(name: "SKProcessRunner", package: "SKProcessRunner"),
            ],
            path: "Sources/CodexCLIKit"
        ),

        .target(
            name: "JsonRPCKit",
            path: "Sources/JsonRPCKit"
        ),

        .target(
            name: "CodexAppServerKit",
            dependencies: [
                "CodexCLIKit",
                "JsonRPCKit",
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
            path: "Sources/ProviderCatalog",
            resources: [
                .process("Resources")
            ]
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
                "CodexBarProviderCatalog",
                "CodexProvider",
                "CopilotProvider",
            ],
            path: "Sources/ProviderUsage"
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
            dependencies: ["Providers", "ProviderCatalog", "CodexBarProviderCatalog", "ProviderUsage", "CodexProvider", "CopilotProvider"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]
        ),
    ]
)
