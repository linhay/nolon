import NolonUIFoundation
import SwiftUI

// MARK: - ResourceCatalogTabScaffolds


public struct ResourceCatalogTabEmptyStateScaffold<Content: View>: View {
    public struct Config {
        public var isEmpty: Bool
        public var searchText: String
        public var emptyState: ResourceCatalogTabEmptyStateConfig
        public var content: () -> Content

        public init(
            isEmpty: Bool,
            searchText: String,
            emptyState: ResourceCatalogTabEmptyStateConfig,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.isEmpty = isEmpty
            self.searchText = searchText
            self.emptyState = emptyState
            self.content = content
        }
    }

    let isEmpty: Bool
    let searchText: String
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let noResultsTitle: String
    let noResultsSystemImage: String
    let noResultsDescription: String
    let content: () -> Content

    public init(config: Config) {
        self.isEmpty = config.isEmpty
        self.searchText = config.searchText
        self.emptyTitle = config.emptyState.emptyTitle
        self.emptySystemImage = config.emptyState.emptySystemImage
        self.emptyDescription = config.emptyState.emptyDescription
        self.noResultsTitle = config.emptyState.noResultsTitle
        self.noResultsSystemImage = config.emptyState.noResultsSystemImage
        self.noResultsDescription = config.emptyState.noResultsDescription
        self.content = config.content
    }

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyState: ResourceCatalogTabEmptyStateConfig,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isEmpty: isEmpty,
                searchText: searchText,
                emptyState: emptyState,
                content: content
            )
        )
    }

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        noResultsTitle: String,
        noResultsSystemImage: String = "magnifyingglass",
        noResultsDescription: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = isEmpty
        self.searchText = searchText
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.noResultsTitle = noResultsTitle
        self.noResultsSystemImage = noResultsSystemImage
        self.noResultsDescription = noResultsDescription
        self.content = content
    }

    public var body: some View {
        ProviderEmptyStateScaffold(
            isEmpty: isEmpty,
            emptyTitle: searchText.isEmpty ? emptyTitle : noResultsTitle,
            emptySystemImage: searchText.isEmpty ? emptySystemImage : noResultsSystemImage,
            emptyDescription: searchText.isEmpty ? emptyDescription : noResultsDescription
        ) {
            content()
        }
    }
}

public struct ResourceCatalogTabEmptyStateConfig: Sendable, Hashable {
    public let emptyTitle: String
    public let emptySystemImage: String
    public let emptyDescription: String
    public let noResultsTitle: String
    public let noResultsSystemImage: String
    public let noResultsDescription: String

    public init(
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        noResultsTitle: String,
        noResultsSystemImage: String,
        noResultsDescription: String
    ) {
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.noResultsTitle = noResultsTitle
        self.noResultsSystemImage = noResultsSystemImage
        self.noResultsDescription = noResultsDescription
    }
}

public struct ResourceCatalogTabSectionTitles: Sendable, Hashable {
    public let installedTitle: String
    public let installingTitle: String
    public let availableTitle: String

    public init(
        installedTitle: String,
        installingTitle: String,
        availableTitle: String
    ) {
        self.installedTitle = installedTitle
        self.installingTitle = installingTitle
        self.availableTitle = availableTitle
    }

    public static let standard = ResourceCatalogTabSectionTitles(
        installedTitle: NSLocalizedString("remote.section.installed", value: "Installed", comment: "Installed section"),
        installingTitle: NSLocalizedString("remote.section.installing", value: "Installing", comment: "Installing section"),
        availableTitle: NSLocalizedString("remote.section.available", value: "Available", comment: "Available section")
    )
}


public struct ResourceCatalogTabStateSectionsScaffold<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    public struct Config {
        public var isEmpty: Bool
        public var searchText: String
        public var emptyState: ResourceCatalogTabEmptyStateConfig
        public var sectionTitles: ResourceCatalogTabSectionTitles
        public var installedItems: [Item]
        public var installingItems: [Item]
        public var availableItems: [Item]
        public var columns: [GridItem]
        public var installedContent: (Item) -> InstalledContent
        public var installingContent: (Item) -> InstallingContent
        public var availableContent: (Item) -> AvailableContent
        public var footerContent: () -> FooterContent

        public init(
            isEmpty: Bool,
            searchText: String,
            emptyState: ResourceCatalogTabEmptyStateConfig,
            sectionTitles: ResourceCatalogTabSectionTitles,
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
            self.emptyState = emptyState
            self.sectionTitles = sectionTitles
            self.installedItems = installedItems
            self.installingItems = installingItems
            self.availableItems = availableItems
            self.columns = columns
            self.installedContent = installedContent
            self.installingContent = installingContent
            self.availableContent = availableContent
            self.footerContent = footerContent
        }
    }

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

    public init(config: Config) {
        self.isEmpty = config.isEmpty
        self.searchText = config.searchText
        self.emptyTitle = config.emptyState.emptyTitle
        self.emptySystemImage = config.emptyState.emptySystemImage
        self.emptyDescription = config.emptyState.emptyDescription
        self.noResultsTitle = config.emptyState.noResultsTitle
        self.noResultsDescription = config.emptyState.noResultsDescription
        self.installedTitle = config.sectionTitles.installedTitle
        self.installingTitle = config.sectionTitles.installingTitle
        self.availableTitle = config.sectionTitles.availableTitle
        self.installedItems = config.installedItems
        self.installingItems = config.installingItems
        self.availableItems = config.availableItems
        self.columns = config.columns
        self.installedContent = config.installedContent
        self.installingContent = config.installingContent
        self.availableContent = config.availableContent
        self.footerContent = config.footerContent
    }

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyState: ResourceCatalogTabEmptyStateConfig,
        sectionTitles: ResourceCatalogTabSectionTitles,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.init(
            config: Config(
                isEmpty: isEmpty,
                searchText: searchText,
                emptyState: emptyState,
                sectionTitles: sectionTitles,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        )
    }

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
            emptyState: ResourceCatalogTabEmptyStateConfig(
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription,
                noResultsTitle: noResultsTitle,
                noResultsSystemImage: "magnifyingglass",
                noResultsDescription: noResultsDescription
            )
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


public struct ResourceCatalogStandardTabScaffold<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    public struct Config {
        public var isEmpty: Bool
        public var searchText: String
        public var emptyTitle: String
        public var emptySystemImage: String
        public var emptyDescription: String
        public var noResultsTitle: String
        public var noResultsDescription: String
        public var installedItems: [Item]
        public var installingItems: [Item]
        public var availableItems: [Item]
        public var columns: [GridItem]
        public var installedContent: (Item) -> InstalledContent
        public var installingContent: (Item) -> InstallingContent
        public var availableContent: (Item) -> AvailableContent
        public var footerContent: () -> FooterContent

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
    }

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

    public init(config: Config) {
        self.isEmpty = config.isEmpty
        self.searchText = config.searchText
        self.emptyTitle = config.emptyTitle
        self.emptySystemImage = config.emptySystemImage
        self.emptyDescription = config.emptyDescription
        self.noResultsTitle = config.noResultsTitle
        self.noResultsDescription = config.noResultsDescription
        self.installedItems = config.installedItems
        self.installingItems = config.installingItems
        self.availableItems = config.availableItems
        self.columns = config.columns
        self.installedContent = config.installedContent
        self.installingContent = config.installingContent
        self.availableContent = config.availableContent
        self.footerContent = config.footerContent
    }

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
        self.init(
            config: Config(
                isEmpty: isEmpty,
                searchText: searchText,
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription,
                noResultsTitle: noResultsTitle,
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
        )
    }

    public var body: some View {
        let emptyState = ResourceCatalogTabEmptyStateConfig(
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            emptyDescription: emptyDescription,
            noResultsTitle: noResultsTitle,
            noResultsSystemImage: "magnifyingglass",
            noResultsDescription: noResultsDescription
        )
        ResourceCatalogTabStateSectionsScaffold(
            isEmpty: isEmpty,
            searchText: searchText,
            emptyState: emptyState,
            sectionTitles: .standard,
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

    var emptyState: ResourceCatalogTabEmptyStateConfig {
        ResourceCatalogTabEmptyStateConfig(
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            emptyDescription: emptyDescription,
            noResultsTitle: NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
            noResultsSystemImage: "magnifyingglass",
            noResultsDescription: noResultsDescription
        )
    }
}

public struct ResourceCatalogKindTabScaffold<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    public struct Config {
        public var kind: ResourceCatalogTabKind
        public var isEmpty: Bool
        public var searchText: String
        public var emptyDescription: String?
        public var noResultsDescription: String?
        public var installedItems: [Item]
        public var installingItems: [Item]
        public var availableItems: [Item]
        public var columns: [GridItem]
        public var installedContent: (Item) -> InstalledContent
        public var installingContent: (Item) -> InstallingContent
        public var availableContent: (Item) -> AvailableContent
        public var footerContent: () -> FooterContent

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
            self.emptyDescription = emptyDescription
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
    }

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

    public init(config: Config) {
        self.kind = config.kind
        self.isEmpty = config.isEmpty
        self.searchText = config.searchText
        self.emptyDescription = config.emptyDescription ?? config.kind.emptyDescription
        self.noResultsDescription = config.noResultsDescription ?? config.kind.noResultsDescription
        self.installedItems = config.installedItems
        self.installingItems = config.installingItems
        self.availableItems = config.availableItems
        self.columns = config.columns
        self.installedContent = config.installedContent
        self.installingContent = config.installingContent
        self.availableContent = config.availableContent
        self.footerContent = config.footerContent
    }

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
        self.init(
            config: Config(
                kind: kind,
                isEmpty: isEmpty,
                searchText: searchText,
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
        )
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


// MARK: - UnifiedRemoteCoreScaffolds

public struct ResourceCatalogMainScaffoldView<Content: View>: View {
    public struct Config {
        public var hasRepository: Bool
        public var hasSelectedTab: Bool
        public var placeholders: ResourceCatalogMainPlaceholderConfig
        public var content: () -> Content

        public init(
            hasRepository: Bool,
            hasSelectedTab: Bool,
            placeholders: ResourceCatalogMainPlaceholderConfig,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.hasRepository = hasRepository
            self.hasSelectedTab = hasSelectedTab
            self.placeholders = placeholders
            self.content = content
        }
    }

    let hasRepository: Bool
    let hasSelectedTab: Bool
    let noRepositoryTitle: String
    let noRepositorySystemImage: String
    let noTabTitle: String
    let noTabSystemImage: String
    let content: () -> Content

    public init(config: Config) {
        self.hasRepository = config.hasRepository
        self.hasSelectedTab = config.hasSelectedTab
        self.noRepositoryTitle = config.placeholders.noRepositoryTitle
        self.noRepositorySystemImage = config.placeholders.noRepositorySystemImage
        self.noTabTitle = config.placeholders.noTabTitle
        self.noTabSystemImage = config.placeholders.noTabSystemImage
        self.content = config.content
    }

    public init(
        hasRepository: Bool,
        hasSelectedTab: Bool,
        placeholders: ResourceCatalogMainPlaceholderConfig,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                hasRepository: hasRepository,
                hasSelectedTab: hasSelectedTab,
                placeholders: placeholders,
                content: content
            )
        )
    }

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
        self.init(
            config: Config(
                hasRepository: hasRepository,
                hasSelectedTab: hasSelectedTab,
                placeholders: ResourceCatalogMainPlaceholderConfig(
                    noRepositoryTitle: noRepositoryTitle,
                    noRepositorySystemImage: noRepositorySystemImage,
                    noTabTitle: noTabTitle,
                    noTabSystemImage: noTabSystemImage
                ),
                content: content
            )
        )
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

public struct ResourceCatalogMainPlaceholderConfig {
    public let noRepositoryTitle: String
    public let noRepositorySystemImage: String
    public let noTabTitle: String
    public let noTabSystemImage: String

    public init(
        noRepositoryTitle: String = NSLocalizedString(
            "detail.no_repository",
            comment: "Select a Repository"
        ),
        noRepositorySystemImage: String = "tray",
        noTabTitle: String = NSLocalizedString(
            "detail.select_tab",
            comment: "Select a Tab"
        ),
        noTabSystemImage: String = "list.bullet"
    ) {
        self.noRepositoryTitle = noRepositoryTitle
        self.noRepositorySystemImage = noRepositorySystemImage
        self.noTabTitle = noTabTitle
        self.noTabSystemImage = noTabSystemImage
    }
}

public struct ResourceCatalogSheetsPresenter<
    Content: View,
    WorkflowItem: Identifiable,
    MCPItem: Identifiable,
    DeleteItem: Identifiable,
    WorkflowSheet: View,
    MCPSheet: View,
    DeleteSheet: View
>: View {
    public struct Config {
        public var selectedWorkflow: Binding<WorkflowItem?>
        public var selectedMCP: Binding<MCPItem?>
        public var deleteRequest: Binding<DeleteItem?>
        public var content: () -> Content
        public var workflowSheet: (WorkflowItem) -> WorkflowSheet
        public var mcpSheet: (MCPItem) -> MCPSheet
        public var deleteSheet: (DeleteItem) -> DeleteSheet

        public init(
            selectedWorkflow: Binding<WorkflowItem?>,
            selectedMCP: Binding<MCPItem?>,
            deleteRequest: Binding<DeleteItem?>,
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder workflowSheet: @escaping (WorkflowItem) -> WorkflowSheet,
            @ViewBuilder mcpSheet: @escaping (MCPItem) -> MCPSheet,
            @ViewBuilder deleteSheet: @escaping (DeleteItem) -> DeleteSheet
        ) {
            self.selectedWorkflow = selectedWorkflow
            self.selectedMCP = selectedMCP
            self.deleteRequest = deleteRequest
            self.content = content
            self.workflowSheet = workflowSheet
            self.mcpSheet = mcpSheet
            self.deleteSheet = deleteSheet
        }
    }

    @Binding var selectedWorkflow: WorkflowItem?
    @Binding var selectedMCP: MCPItem?
    @Binding var deleteRequest: DeleteItem?
    let content: () -> Content
    let workflowSheet: (WorkflowItem) -> WorkflowSheet
    let mcpSheet: (MCPItem) -> MCPSheet
    let deleteSheet: (DeleteItem) -> DeleteSheet

    public init(config: Config) {
        self._selectedWorkflow = config.selectedWorkflow
        self._selectedMCP = config.selectedMCP
        self._deleteRequest = config.deleteRequest
        self.content = config.content
        self.workflowSheet = config.workflowSheet
        self.mcpSheet = config.mcpSheet
        self.deleteSheet = config.deleteSheet
    }

    public init(
        selectedWorkflow: Binding<WorkflowItem?>,
        selectedMCP: Binding<MCPItem?>,
        deleteRequest: Binding<DeleteItem?>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder workflowSheet: @escaping (WorkflowItem) -> WorkflowSheet,
        @ViewBuilder mcpSheet: @escaping (MCPItem) -> MCPSheet,
        @ViewBuilder deleteSheet: @escaping (DeleteItem) -> DeleteSheet
    ) {
        self.init(
            config: Config(
                selectedWorkflow: selectedWorkflow,
                selectedMCP: selectedMCP,
                deleteRequest: deleteRequest,
                content: content,
                workflowSheet: workflowSheet,
                mcpSheet: mcpSheet,
                deleteSheet: deleteSheet
            )
        )
    }

    public var body: some View {
        content()
            .sheet(item: $selectedWorkflow) { workflow in
                workflowSheet(workflow)
            }
            .sheet(item: $selectedMCP) { mcp in
                mcpSheet(mcp)
            }
            .sheet(item: $deleteRequest) { request in
                deleteSheet(request)
            }
    }
}

public struct ResourceCatalogGridSection<Data: RandomAccessCollection, CardContent: View>: View where Data.Element: Identifiable {
    public struct Config {
        public var title: String
        public var items: Data
        public var columns: [GridItem]
        public var spacing: CGFloat
        public var cardContent: (Data.Element) -> CardContent

        public init(
            title: String,
            items: Data,
            columns: [GridItem],
            spacing: CGFloat = 16,
            @ViewBuilder cardContent: @escaping (Data.Element) -> CardContent
        ) {
            self.title = title
            self.items = items
            self.columns = columns
            self.spacing = spacing
            self.cardContent = cardContent
        }
    }

    let title: String
    let items: Data
    let columns: [GridItem]
    let spacing: CGFloat
    let cardContent: (Data.Element) -> CardContent

    public init(config: Config) {
        self.title = config.title
        self.items = config.items
        self.columns = config.columns
        self.spacing = config.spacing
        self.cardContent = config.cardContent
    }

    public init(
        title: String,
        items: Data,
        columns: [GridItem],
        spacing: CGFloat = 16,
        @ViewBuilder cardContent: @escaping (Data.Element) -> CardContent
    ) {
        self.init(
            config: Config(
                title: title,
                items: items,
                columns: columns,
                spacing: spacing,
                cardContent: cardContent
            )
        )
    }

    public var body: some View {
        if !items.isEmpty {
            ResourceCatalogSectionBlock(title: title, count: items.count) {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(items) { item in
                        cardContent(item)
                    }
                }
            }
        }
    }
}

public struct RepositoryRowContextMenuView<TrailingContent: View>: View {
    public struct Config {
        public var syncTitle: String
        public var revealTitle: String
        public var editTitle: String
        public var removeTitle: String
        public var onSync: (() -> Void)?
        public var onRevealInFinder: (() -> Void)?
        public var onEdit: (() -> Void)?
        public var onRemove: (() -> Void)?
        public var trailingContent: () -> TrailingContent

        public init(
            syncTitle: String = "Sync",
            revealTitle: String = "Reveal in Finder",
            editTitle: String = "Edit",
            removeTitle: String = "Remove",
            onSync: (() -> Void)? = nil,
            onRevealInFinder: (() -> Void)? = nil,
            onEdit: (() -> Void)? = nil,
            onRemove: (() -> Void)? = nil,
            @ViewBuilder trailingContent: @escaping () -> TrailingContent
        ) {
            self.syncTitle = syncTitle
            self.revealTitle = revealTitle
            self.editTitle = editTitle
            self.removeTitle = removeTitle
            self.onSync = onSync
            self.onRevealInFinder = onRevealInFinder
            self.onEdit = onEdit
            self.onRemove = onRemove
            self.trailingContent = trailingContent
        }
    }

    let syncTitle: String
    let revealTitle: String
    let editTitle: String
    let removeTitle: String
    let onSync: (() -> Void)?
    let onRevealInFinder: (() -> Void)?
    let onEdit: (() -> Void)?
    let onRemove: (() -> Void)?
    let trailingContent: () -> TrailingContent

    public init(config: Config) {
        self.syncTitle = config.syncTitle
        self.revealTitle = config.revealTitle
        self.editTitle = config.editTitle
        self.removeTitle = config.removeTitle
        self.onSync = config.onSync
        self.onRevealInFinder = config.onRevealInFinder
        self.onEdit = config.onEdit
        self.onRemove = config.onRemove
        self.trailingContent = config.trailingContent
    }

    public init(
        syncTitle: String = "Sync",
        revealTitle: String = "Reveal in Finder",
        editTitle: String = "Edit",
        removeTitle: String = "Remove",
        onSync: (() -> Void)? = nil,
        onRevealInFinder: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.init(
            config: Config(
                syncTitle: syncTitle,
                revealTitle: revealTitle,
                editTitle: editTitle,
                removeTitle: removeTitle,
                onSync: onSync,
                onRevealInFinder: onRevealInFinder,
                onEdit: onEdit,
                onRemove: onRemove,
                trailingContent: trailingContent
            )
        )
    }

    public var body: some View {
        if let onSync {
            Button {
                onSync()
            } label: {
                Label(syncTitle, systemImage: "arrow.triangle.2.circlepath")
                    .dsIconLabelButton()
            }
        }

        if let onRevealInFinder {
            Button {
                onRevealInFinder()
            } label: {
                Label(revealTitle, systemImage: "folder")
                    .dsIconLabelButton()
            }
        }

        if let onEdit {
            Button {
                onEdit()
            } label: {
                Label(editTitle, systemImage: "pencil")
                    .dsIconLabelButton()
            }
        }

        if let onRemove {
            Divider()
            ContextMenuDestructiveButton(
                title: removeTitle,
                systemImage: "trash"
            ) {
                onRemove()
            }
        }

        trailingContent()
    }
}

private struct RemoteDetailSheetFrameModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.frame(
            minWidth: 920,
            idealWidth: 1100,
            maxWidth: .infinity,
            minHeight: 620,
            idealHeight: 720,
            maxHeight: .infinity
        )
    }
}

public extension View {
    func remoteDetailSheetFrame() -> some View {
        modifier(RemoteDetailSheetFrameModifier())
    }
}

// MARK: - UnifiedResourceCatalogSupportViews

public struct CircularIconActionButton: View {
    public struct Config {
        public var systemImage: String
        public var help: String
        public var action: () -> Void

        public init(
            systemImage: String,
            help: String,
            action: @escaping () -> Void
        ) {
            self.systemImage = systemImage
            self.help = help
            self.action = action
        }
    }

    let systemImage: String
    let help: String
    let action: () -> Void

    public init(config: Config) {
        self.systemImage = config.systemImage
        self.help = config.help
        self.action = config.action
    }

    public init(
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                systemImage: systemImage,
                help: help,
                action: action
            )
        )
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                        .background(
                            Circle()
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

public struct ResourceCatalogToolbarView: View {
    public struct Config {
        public var searchText: Binding<String>
        public var isSearching: Bool
        public var config: ResourceCatalogToolbarConfig
        public var onRefresh: (() -> Void)?
        public var onClose: (() -> Void)?

        public init(
            searchText: Binding<String>,
            isSearching: Bool,
            config: ResourceCatalogToolbarConfig = ResourceCatalogToolbarConfig(),
            onRefresh: (() -> Void)? = nil,
            onClose: (() -> Void)? = nil
        ) {
            self.searchText = searchText
            self.isSearching = isSearching
            self.config = config
            self.onRefresh = onRefresh
            self.onClose = onClose
        }
    }

    @Binding var searchText: String
    let isSearching: Bool
    let searchPlaceholder: String
    let onRefresh: (() -> Void)?
    let onClose: (() -> Void)?

    public init(config: Config) {
        self._searchText = config.searchText
        self.isSearching = config.isSearching
        self.searchPlaceholder = config.config.searchPlaceholder
        self.onRefresh = config.onRefresh
        self.onClose = config.onClose
    }

    public init(
        searchText: Binding<String>,
        isSearching: Bool,
        config: ResourceCatalogToolbarConfig,
        onRefresh: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.init(
            config: Config(
                searchText: searchText,
                isSearching: isSearching,
                config: config,
                onRefresh: onRefresh,
                onClose: onClose
            )
        )
    }

    public init(
        searchText: Binding<String>,
        isSearching: Bool,
        searchPlaceholder: String = NSLocalizedString(
            "remote.search.placeholder",
            value: "Search",
            comment: "Search placeholder"
        ),
        onRefresh: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.init(
            config: Config(
                searchText: searchText,
                isSearching: isSearching,
                config: ResourceCatalogToolbarConfig(searchPlaceholder: searchPlaceholder),
                onRefresh: onRefresh,
                onClose: onClose
            )
        )
    }

    public var body: some View {
        HStack(spacing: 12) {
            SearchField(
                config: .init(
                    placeholder: searchPlaceholder,
                    text: $searchText,
                    showSearching: isSearching
                )
            )
            .frame(maxWidth: .infinity)

            if let onRefresh {
                CircularIconActionButton(
                    systemImage: "arrow.clockwise",
                    help: NSLocalizedString("Refresh", comment: "Refresh"),
                    action: onRefresh
                )
            }
            if let onClose {
                ResourceCenterCloseButton(action: onClose)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

public struct ResourceCatalogToolbarConfig {
    public let searchPlaceholder: String

    public init(
        searchPlaceholder: String = NSLocalizedString(
            "remote.search.placeholder",
            value: "Search",
            comment: "Search placeholder"
        )
    ) {
        self.searchPlaceholder = searchPlaceholder
    }
}

public struct ResourceCatalogSectionBlock<Content: View>: View {
    public struct Config {
        public var header: ResourceCatalogSectionHeaderConfig
        public var content: () -> Content

        public init(
            header: ResourceCatalogSectionHeaderConfig,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.header = header
            self.content = content
        }
    }

    let title: String
    let count: Int
    let content: () -> Content

    public init(config: Config) {
        self.title = config.header.title
        self.count = config.header.count
        self.content = config.content
    }

    public init(
        config: ResourceCatalogSectionHeaderConfig,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(config: Config(header: config, content: content))
    }

    public init(
        title: String,
        count: Int,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                header: ResourceCatalogSectionHeaderConfig(title: title, count: count),
                content: content
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .dsBadge(
                        foreground: DesignSystem.Colors.Text.secondary,
                        background: DesignSystem.Colors.Component.controlFillSubtle
                    )
                Spacer()
            }
            .padding(.top, 2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct ResourceCatalogSectionHeaderConfig {
    public let title: String
    public let count: Int

    public init(title: String, count: Int) {
        self.title = title
        self.count = count
    }
}

public struct InlineWarningBannerView: View {
    public struct Config {
        public var message: String
        public var retryTitle: String
        public var onRetry: () -> Void

        public init(
            message: String,
            retryTitle: String,
            onRetry: @escaping () -> Void
        ) {
            self.message = message
            self.retryTitle = retryTitle
            self.onRetry = onRetry
        }
    }

    let message: String
    let retryTitle: String
    let onRetry: () -> Void

    public init(config: Config) {
        self.message = config.message
        self.retryTitle = config.retryTitle
        self.onRetry = config.onRetry
    }

    public init(
        config: InlineWarningBannerConfig,
        onRetry: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                message: config.message,
                retryTitle: config.retryTitle,
                onRetry: onRetry
            )
        )
    }

    public init(
        message: String,
        retryTitle: String,
        onRetry: @escaping () -> Void
    ) {
        self.init(config: Config(message: message, retryTitle: retryTitle, onRetry: onRetry))
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            Text(message)
                .font(.callout)
                .dsSecondaryText(font: .callout)
                .lineLimit(2)
            Spacer()
            Button(retryTitle) {
                onRetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.10),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.28),
            borderWidth: 1
        )
        .padding(.horizontal)
    }
}

public struct InlineWarningBannerConfig {
    public let message: String
    public let retryTitle: String

    public init(
        message: String,
        retryTitle: String
    ) {
        self.message = message
        self.retryTitle = retryTitle
    }
}

public struct ResourceCatalogPlaceholderView: View {
    public struct Config {
        public var title: String
        public var systemImage: String

        public init(
            title: String,
            systemImage: String
        ) {
            self.title = title
            self.systemImage = systemImage
        }
    }

    let title: String
    let systemImage: String

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
    }

    public init(config: ResourceCatalogPlaceholderConfig) {
        self.init(config: Config(title: config.title, systemImage: config.systemImage))
    }

    public init(title: String, systemImage: String) {
        self.init(config: Config(title: title, systemImage: systemImage))
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .dsEmptyStateTitle()
            } icon: {
                Image(systemName: systemImage)
                    .dsEmptyStateIcon()
            }
        }
    }
}

public struct ResourceCatalogPlaceholderConfig {
    public let title: String
    public let systemImage: String

    public init(
        title: String,
        systemImage: String
    ) {
        self.title = title
        self.systemImage = systemImage
    }
}

public struct CenteredLoadingIndicatorView: View {
    public struct Config {
        public init() {}
    }

    public init(config: Config) {
        _ = config
    }

    public init() {
        self.init(config: Config())
    }

    public var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(DesignSystem.Colors.Status.info)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct ResourceCatalogErrorStateView: View {
    public struct Config {
        public var data: ResourceCatalogErrorStateConfig
        public var onCopyMessage: () -> Void
        public var onRetry: () -> Void

        public init(
            data: ResourceCatalogErrorStateConfig,
            onCopyMessage: @escaping () -> Void,
            onRetry: @escaping () -> Void
        ) {
            self.data = data
            self.onCopyMessage = onCopyMessage
            self.onRetry = onRetry
        }
    }

    let title: String
    let message: String
    let retryTitle: String
    let onCopyMessage: () -> Void
    let onRetry: () -> Void

    public init(config: Config) {
        self.title = config.data.title
        self.message = config.data.message
        self.retryTitle = config.data.retryTitle
        self.onCopyMessage = config.onCopyMessage
        self.onRetry = config.onRetry
    }

    public init(
        config: ResourceCatalogErrorStateConfig,
        onCopyMessage: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: config,
                onCopyMessage: onCopyMessage,
                onRetry: onRetry
            )
        )
    }

    public init(
        title: String,
        message: String,
        retryTitle: String,
        onCopyMessage: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onCopyMessage = onCopyMessage
        self.onRetry = onRetry
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .dsEmptyStateErrorTitle()
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .dsEmptyStateIcon(color: DesignSystem.Colors.Status.error)
            }
        } description: {
            Button {
                onCopyMessage()
            } label: {
                Text(message)
                    .dsSecondaryText(font: .body)
            }
            .buttonStyle(.plain)
        } actions: {
            Button {
                onRetry()
            } label: {
                Text(retryTitle)
            }
            .buttonStyle(.bordered)
        }
    }
}

public struct ResourceCatalogErrorStateConfig {
    public let title: String
    public let message: String
    public let retryTitle: String

    public init(
        title: String,
        message: String,
        retryTitle: String
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
    }
}

public struct ResourceCatalogBodyStateContainerView<Content: View>: View {
    public struct Config {
        public var isLoading: Bool
        public var hasAnyContent: Bool
        public var errorMessage: String?
        public var errorConfig: ResourceCatalogLoadErrorConfig
        public var onCopyError: (String) -> Void
        public var onRetry: () -> Void
        public var content: () -> Content

        public init(
            isLoading: Bool,
            hasAnyContent: Bool,
            errorMessage: String?,
            errorConfig: ResourceCatalogLoadErrorConfig,
            onCopyError: @escaping (String) -> Void,
            onRetry: @escaping () -> Void,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.isLoading = isLoading
            self.hasAnyContent = hasAnyContent
            self.errorMessage = errorMessage
            self.errorConfig = errorConfig
            self.onCopyError = onCopyError
            self.onRetry = onRetry
            self.content = content
        }
    }

    let isLoading: Bool
    let hasAnyContent: Bool
    let errorMessage: String?
    let loadErrorTitle: String
    let retryTitle: String
    let onCopyError: (String) -> Void
    let onRetry: () -> Void
    let content: () -> Content

    public init(config: Config) {
        self.isLoading = config.isLoading
        self.hasAnyContent = config.hasAnyContent
        self.errorMessage = config.errorMessage
        self.loadErrorTitle = config.errorConfig.title
        self.retryTitle = config.errorConfig.retryTitle
        self.onCopyError = config.onCopyError
        self.onRetry = config.onRetry
        self.content = config.content
    }

    public init(
        isLoading: Bool,
        hasAnyContent: Bool,
        errorMessage: String?,
        errorConfig: ResourceCatalogLoadErrorConfig,
        onCopyError: @escaping (String) -> Void,
        onRetry: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isLoading: isLoading,
                hasAnyContent: hasAnyContent,
                errorMessage: errorMessage,
                errorConfig: errorConfig,
                onCopyError: onCopyError,
                onRetry: onRetry,
                content: content
            )
        )
    }

    public init(
        isLoading: Bool,
        hasAnyContent: Bool,
        errorMessage: String?,
        loadErrorTitle: String = NSLocalizedString(
            "remote.error.title",
            value: "Error Loading Data",
            comment: "Remote load error title"
        ),
        retryTitle: String = NSLocalizedString(
            "remote.retry",
            value: "Retry",
            comment: "Retry"
        ),
        onCopyError: @escaping (String) -> Void,
        onRetry: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isLoading: isLoading,
                hasAnyContent: hasAnyContent,
                errorMessage: errorMessage,
                errorConfig: ResourceCatalogLoadErrorConfig(
                    title: loadErrorTitle,
                    retryTitle: retryTitle
                ),
                onCopyError: onCopyError,
                onRetry: onRetry,
                content: content
            )
        )
    }

    public var body: some View {
        if isLoading && !hasAnyContent {
            CenteredLoadingIndicatorView()
        } else if let error = errorMessage, !hasAnyContent {
            ResourceCatalogErrorStateView(
                config: ResourceCatalogErrorStateConfig(
                    title: loadErrorTitle,
                    message: error,
                    retryTitle: retryTitle
                ),
                onCopyMessage: {
                    onCopyError(error)
                },
                onRetry: onRetry
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 10) {
                if let error = errorMessage, !error.isEmpty {
                    InlineWarningBannerView(
                        message: error,
                        retryTitle: retryTitle,
                        onRetry: onRetry
                    )
                }
                content()
            }
        }
    }
}

public struct ResourceCatalogLoadErrorConfig {
    public let title: String
    public let retryTitle: String

    public init(
        title: String = NSLocalizedString(
            "remote.error.title",
            value: "Error Loading Data",
            comment: "Remote load error title"
        ),
        retryTitle: String = NSLocalizedString(
            "remote.retry",
            value: "Retry",
            comment: "Retry"
        )
    ) {
        self.title = title
        self.retryTitle = retryTitle
    }
}

public struct ResourceCatalogGridOverlayScaffold<Content: View, Overlay: View>: View {
    public struct Config {
        public var contentPadding: EdgeInsets
        public var showOverlay: Bool
        public var content: () -> Content
        public var overlay: () -> Overlay

        public init(
            contentPadding: EdgeInsets,
            showOverlay: Bool,
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder overlay: @escaping () -> Overlay
        ) {
            self.contentPadding = contentPadding
            self.showOverlay = showOverlay
            self.content = content
            self.overlay = overlay
        }
    }

    let contentPadding: EdgeInsets
    let showOverlay: Bool
    let content: () -> Content
    let overlay: () -> Overlay

    public init(config: Config) {
        self.contentPadding = config.contentPadding
        self.showOverlay = config.showOverlay
        self.content = config.content
        self.overlay = config.overlay
    }

    public init(
        config: ResourceCatalogGridOverlayConfig,
        showOverlay: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.init(
            config: Config(
                contentPadding: config.contentPadding,
                showOverlay: showOverlay,
                content: content,
                overlay: overlay
            )
        )
    }

    public init(
        contentPadding: EdgeInsets = EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16),
        showOverlay: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.init(
            config: Config(
                contentPadding: contentPadding,
                showOverlay: showOverlay,
                content: content,
                overlay: overlay
            )
        )
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PaddedScrollContainer(
                padding: contentPadding
            ) {
                content()
            }
        }
        .bottomTrailingOverlay(isPresented: showOverlay) {
            overlay()
        }
    }
}

public struct ResourceCatalogGridOverlayConfig {
    public let contentPadding: EdgeInsets

    public init(
        contentPadding: EdgeInsets = EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
    ) {
        self.contentPadding = contentPadding
    }
}
