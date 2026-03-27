import SwiftUI

public struct ProviderMcpConfigScaffoldView<
    NoConfigView: View,
    NoServersView: View,
    NoResultsView: View,
    ContentView: View
>: View {
    let supportsNativeConfig: Bool
    let configExists: Bool
    let isSearching: Bool
    let hasFilteredServers: Bool
    let unsupportedTitle: String
    let unsupportedSystemImage: String
    let unsupportedDescription: String
    let noConfigView: () -> NoConfigView
    let noServersView: () -> NoServersView
    let noResultsView: () -> NoResultsView
    let contentView: () -> ContentView

    public init(
        supportsNativeConfig: Bool,
        configExists: Bool,
        isSearching: Bool,
        hasFilteredServers: Bool,
        unsupportedTitle: String = NSLocalizedString(
            "mcp.not_supported",
            value: "MCP Not Supported",
            comment: "MCP unsupported title"
        ),
        unsupportedSystemImage: String = "exclamationmark.triangle",
        unsupportedDescription: String = NSLocalizedString(
            "mcp.not_supported_desc",
            value: "This provider does not support MCP configuration",
            comment: "MCP unsupported description"
        ),
        @ViewBuilder noConfigView: @escaping () -> NoConfigView,
        @ViewBuilder noServersView: @escaping () -> NoServersView,
        @ViewBuilder noResultsView: @escaping () -> NoResultsView,
        @ViewBuilder contentView: @escaping () -> ContentView
    ) {
        self.supportsNativeConfig = supportsNativeConfig
        self.configExists = configExists
        self.isSearching = isSearching
        self.hasFilteredServers = hasFilteredServers
        self.unsupportedTitle = unsupportedTitle
        self.unsupportedSystemImage = unsupportedSystemImage
        self.unsupportedDescription = unsupportedDescription
        self.noConfigView = noConfigView
        self.noServersView = noServersView
        self.noResultsView = noResultsView
        self.contentView = contentView
    }

    public var body: some View {
        if !supportsNativeConfig {
            McpConfigUnsupportedStateView(
                title: unsupportedTitle,
                systemImage: unsupportedSystemImage,
                description: unsupportedDescription
            )
        } else {
            McpConfigStateContainerView(
                configExists: configExists,
                isSearching: isSearching,
                hasFilteredServers: hasFilteredServers
            ) {
                noConfigView()
            } noServersView: {
                noServersView()
            } noResultsView: {
                noResultsView()
            } contentView: {
                contentView()
            }
        }
    }
}
