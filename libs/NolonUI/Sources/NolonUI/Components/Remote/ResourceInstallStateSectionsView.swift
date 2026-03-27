import SwiftUI

public struct ResourceInstallStateSectionsView<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
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
        VStack(alignment: .leading, spacing: 20) {
            ResourceCatalogGridSection(
                title: installedTitle,
                items: installedItems,
                columns: columns
            ) { item in
                installedContent(item)
            }
            ResourceCatalogGridSection(
                title: installingTitle,
                items: installingItems,
                columns: columns
            ) { item in
                installingContent(item)
            }
            ResourceCatalogGridSection(
                title: availableTitle,
                items: availableItems,
                columns: columns
            ) { item in
                availableContent(item)
            }
            footerContent()
        }
    }
}
