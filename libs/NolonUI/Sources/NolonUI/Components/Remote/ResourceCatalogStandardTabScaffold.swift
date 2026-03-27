import SwiftUI

public struct ResourceCatalogStandardTabScaffold<
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
        noResultsTitle: String = NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
        noResultsDescription: String,
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
        ResourceCatalogTabStateSectionsScaffold(
            isEmpty: isEmpty,
            searchText: searchText,
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            emptyDescription: emptyDescription,
            noResultsTitle: noResultsTitle,
            noResultsDescription: noResultsDescription,
            installedTitle: NSLocalizedString("remote.section.installed", value: "Installed", comment: "Installed section"),
            installingTitle: NSLocalizedString("remote.section.installing", value: "Installing", comment: "Installing section"),
            availableTitle: NSLocalizedString("remote.section.available", value: "Available", comment: "Available section"),
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
