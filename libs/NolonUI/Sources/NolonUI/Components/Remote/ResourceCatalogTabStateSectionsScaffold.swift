import SwiftUI

public struct ResourceCatalogTabStateSectionsScaffold<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    let isEmpty: Bool
    let searchText: String
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let noResultsTitle: String
    let noResultsDescription: String
    let installedTitle: String
    let installingTitle: String
    let availableTitle: String
    let installedItems: [Item]
    let installingItems: [Item]
    let availableItems: [Item]
    let columns: [GridItem]
    let installedContent: (Item) -> InstalledContent
    let installingContent: (Item) -> InstallingContent
    let availableContent: (Item) -> AvailableContent
    let footerContent: () -> FooterContent

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        noResultsTitle: String,
        noResultsDescription: String,
        installedTitle: String,
        installingTitle: String,
        availableTitle: String,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.isEmpty = isEmpty
        self.searchText = searchText
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.noResultsTitle = noResultsTitle
        self.noResultsDescription = noResultsDescription
        self.installedTitle = installedTitle
        self.installingTitle = installingTitle
        self.availableTitle = availableTitle
        self.installedItems = installedItems
        self.installingItems = installingItems
        self.availableItems = availableItems
        self.columns = columns
        self.installedContent = installedContent
        self.installingContent = installingContent
        self.availableContent = availableContent
        self.footerContent = footerContent
    }

    public var body: some View {
        ResourceCatalogTabEmptyStateScaffold(
            isEmpty: isEmpty,
            searchText: searchText,
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            emptyDescription: emptyDescription,
            noResultsTitle: noResultsTitle,
            noResultsDescription: noResultsDescription
        ) {
            ResourceInstallStateSectionsView(
                installedTitle: installedTitle,
                installingTitle: installingTitle,
                availableTitle: availableTitle,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        }
    }
}
