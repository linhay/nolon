import SwiftUI

public enum ResourceCatalogTabKind {
    case skills
    case workflows
    case mcps

    var emptyTitle: String {
        switch self {
        case .skills:
            return NSLocalizedString("skills.empty", comment: "No Skills")
        case .workflows:
            return NSLocalizedString("remote.workflows.empty", value: "No Workflows", comment: "No workflows")
        case .mcps:
            return NSLocalizedString("remote.mcps.empty", value: "No MCPs", comment: "No MCPs")
        }
    }

    var emptySystemImage: String {
        switch self {
        case .skills:
            return "square.grid.2x2"
        case .workflows:
            return "arrow.triangle.branch"
        case .mcps:
            return "server.rack"
        }
    }

    var emptyDescription: String {
        switch self {
        case .skills:
            return NSLocalizedString("skills.empty_desc", comment: "No skills in this repository")
        case .workflows:
            return NSLocalizedString(
                "remote.workflows.empty_desc",
                value: "No workflows in this repository",
                comment: "No workflows description"
            )
        case .mcps:
            return NSLocalizedString(
                "remote.mcps.empty_desc",
                value: "No MCPs in this repository",
                comment: "No MCPs description"
            )
        }
    }

    var noResultsDescription: String {
        switch self {
        case .skills:
            return NSLocalizedString(
                "remote.search.no_results_desc",
                value: "No matching skills found",
                comment: "No search results description"
            )
        case .workflows:
            return NSLocalizedString(
                "remote.search.no_results_desc",
                value: "No matching workflows found",
                comment: "No search results description"
            )
        case .mcps:
            return NSLocalizedString(
                "remote.search.no_results_desc",
                value: "No matching MCPs found",
                comment: "No search results description"
            )
        }
    }
}

public struct ResourceCatalogKindTabScaffold<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    let kind: ResourceCatalogTabKind
    let isEmpty: Bool
    let searchText: String
    let emptyDescription: String
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
        kind: ResourceCatalogTabKind,
        isEmpty: Bool,
        searchText: String,
        emptyDescription: String? = nil,
        noResultsDescription: String? = nil,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.kind = kind
        self.isEmpty = isEmpty
        self.searchText = searchText
        self.emptyDescription = emptyDescription ?? kind.emptyDescription
        self.noResultsDescription = noResultsDescription ?? kind.noResultsDescription
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
        ResourceCatalogStandardTabScaffold(
            isEmpty: isEmpty,
            searchText: searchText,
            emptyTitle: kind.emptyTitle,
            emptySystemImage: kind.emptySystemImage,
            emptyDescription: emptyDescription,
            noResultsDescription: noResultsDescription,
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
