import SwiftUI

public struct ProviderDetailStateContainerView<NoProviderView: View, NoTabView: View, Content: View>: View {
    let hasProvider: Bool
    let hasSelectedTab: Bool
    let isLoading: Bool
    let noProviderView: () -> NoProviderView
    let noTabView: () -> NoTabView
    let content: () -> Content

    public init(
        hasProvider: Bool,
        hasSelectedTab: Bool,
        isLoading: Bool,
        @ViewBuilder noProviderView: @escaping () -> NoProviderView,
        @ViewBuilder noTabView: @escaping () -> NoTabView,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.hasProvider = hasProvider
        self.hasSelectedTab = hasSelectedTab
        self.isLoading = isLoading
        self.noProviderView = noProviderView
        self.noTabView = noTabView
        self.content = content
    }

    public var body: some View {
        if !hasProvider {
            noProviderView()
        } else if !hasSelectedTab {
            noTabView()
        } else if isLoading {
            CenteredLoadingIndicatorView()
        } else {
            content()
        }
    }
}
