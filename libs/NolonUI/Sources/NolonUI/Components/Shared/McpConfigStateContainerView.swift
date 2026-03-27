import SwiftUI

public struct McpConfigStateContainerView<NoConfigView: View, NoServersView: View, NoResultsView: View, ContentView: View>: View {
    let configExists: Bool
    let isSearching: Bool
    let hasFilteredServers: Bool
    let noConfigView: () -> NoConfigView
    let noServersView: () -> NoServersView
    let noResultsView: () -> NoResultsView
    let contentView: () -> ContentView

    public init(
        configExists: Bool,
        isSearching: Bool,
        hasFilteredServers: Bool,
        @ViewBuilder noConfigView: @escaping () -> NoConfigView,
        @ViewBuilder noServersView: @escaping () -> NoServersView,
        @ViewBuilder noResultsView: @escaping () -> NoResultsView,
        @ViewBuilder contentView: @escaping () -> ContentView
    ) {
        self.configExists = configExists
        self.isSearching = isSearching
        self.hasFilteredServers = hasFilteredServers
        self.noConfigView = noConfigView
        self.noServersView = noServersView
        self.noResultsView = noResultsView
        self.contentView = contentView
    }

    public var body: some View {
        if !configExists {
            noConfigView()
        } else if !hasFilteredServers && !isSearching {
            noServersView()
        } else if !hasFilteredServers {
            noResultsView()
        } else {
            contentView()
        }
    }
}
