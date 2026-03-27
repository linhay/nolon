import SwiftUI

public struct ResourceCatalogMainScaffoldView<Content: View>: View {
    let hasRepository: Bool
    let hasSelectedTab: Bool
    let noRepositoryTitle: String
    let noRepositorySystemImage: String
    let noTabTitle: String
    let noTabSystemImage: String
    let content: () -> Content

    public init(
        hasRepository: Bool,
        hasSelectedTab: Bool,
        noRepositoryTitle: String = NSLocalizedString(
            "detail.no_repository",
            comment: "Select a Repository"
        ),
        noRepositorySystemImage: String = "tray",
        noTabTitle: String = NSLocalizedString(
            "detail.select_tab",
            comment: "Select a Tab"
        ),
        noTabSystemImage: String = "list.bullet",
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.hasRepository = hasRepository
        self.hasSelectedTab = hasSelectedTab
        self.noRepositoryTitle = noRepositoryTitle
        self.noRepositorySystemImage = noRepositorySystemImage
        self.noTabTitle = noTabTitle
        self.noTabSystemImage = noTabSystemImage
        self.content = content
    }

    public var body: some View {
        Group {
            if !hasRepository {
                ResourceCatalogPlaceholderView(
                    title: noRepositoryTitle,
                    systemImage: noRepositorySystemImage
                )
            } else if !hasSelectedTab {
                ResourceCatalogPlaceholderView(
                    title: noTabTitle,
                    systemImage: noTabSystemImage
                )
            } else {
                content()
            }
        }
    }
}
