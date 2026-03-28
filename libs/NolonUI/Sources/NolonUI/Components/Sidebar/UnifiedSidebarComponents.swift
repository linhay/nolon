import SwiftUI
import NolonUIFoundation

public enum ProviderContentTabSidebarMetrics {
    public static let headerHeight: CGFloat = SidebarColumnMetrics.headerHeight
    public static let headerHorizontalPadding: CGFloat = SidebarColumnMetrics.headerHorizontalPadding
    public static let columnMinWidth: CGFloat = SidebarColumnMetrics.columnMinWidth
    public static let columnIdealWidth: CGFloat = SidebarColumnMetrics.columnIdealWidth
    public static let columnMaxWidth: CGFloat = SidebarColumnMetrics.columnMaxWidth
}

public struct ProviderContentTabSidebarItem<Tab: Hashable>: Identifiable, Hashable {
    public let id: Tab
    public let title: String
    public let iconName: String
    public let countText: String?
    public let trailingSymbolName: String?
    public let trailingHelpText: String?

    public init(
        id: Tab,
        title: String,
        iconName: String,
        countText: String? = nil,
        trailingSymbolName: String? = nil,
        trailingHelpText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.countText = countText
        self.trailingSymbolName = trailingSymbolName
        self.trailingHelpText = trailingHelpText
    }
}

public struct ProviderContentTabSidebarEmptyStateConfig {
    public var title: String
    public var description: String
    public var systemImage: String

    public init(
        title: String = NSLocalizedString(
            "content.no_provider",
            comment: "Select a Provider"
        ),
        description: String = NSLocalizedString(
            "content.no_provider_desc",
            comment: "Choose a provider from the sidebar"
        ),
        systemImage: String = "sidebar.left"
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
    }
}

public struct ProviderContentTabSidebarConfig<Tab: Hashable> {
    public var hasProviderSelection: Bool
    public var items: [ProviderContentTabSidebarItem<Tab>]
    public var emptyState: ProviderContentTabSidebarEmptyStateConfig
    public var onTapTrailingAccessory: ((Tab) -> Void)?

    public init(
        hasProviderSelection: Bool,
        items: [ProviderContentTabSidebarItem<Tab>],
        emptyState: ProviderContentTabSidebarEmptyStateConfig = ProviderContentTabSidebarEmptyStateConfig(),
        onTapTrailingAccessory: ((Tab) -> Void)? = nil
    ) {
        self.hasProviderSelection = hasProviderSelection
        self.items = items
        self.emptyState = emptyState
        self.onTapTrailingAccessory = onTapTrailingAccessory
    }
}

public struct ProviderContentTabSidebarComponent<Tab: Hashable>: View {
    public struct Config {
        public var selectedTab: Binding<Tab?>
        public var sidebar: ProviderContentTabSidebarConfig<Tab>

        public init(
            selectedTab: Binding<Tab?>,
            sidebar: ProviderContentTabSidebarConfig<Tab>
        ) {
            self.selectedTab = selectedTab
            self.sidebar = sidebar
        }
    }

    @Binding private var selectedTab: Tab?

    private let hasProviderSelection: Bool
    private let items: [ProviderContentTabSidebarItem<Tab>]
    private let emptyTitle: String
    private let emptyDescription: String
    private let emptySystemImage: String
    private let onTapTrailingAccessory: ((Tab) -> Void)?

    public init(config: Config) {
        self.init(selectedTab: config.selectedTab, config: config.sidebar)
    }

    public init(
        selectedTab: Binding<Tab?>,
        config: ProviderContentTabSidebarConfig<Tab>
    ) {
        self._selectedTab = selectedTab
        self.hasProviderSelection = config.hasProviderSelection
        self.items = config.items
        self.emptyTitle = config.emptyState.title
        self.emptyDescription = config.emptyState.description
        self.emptySystemImage = config.emptyState.systemImage
        self.onTapTrailingAccessory = config.onTapTrailingAccessory
    }

    public init(
        selectedTab: Binding<Tab?>,
        hasProviderSelection: Bool,
        items: [ProviderContentTabSidebarItem<Tab>],
        emptyTitle: String = NSLocalizedString(
            "content.no_provider",
            comment: "Select a Provider"
        ),
        emptyDescription: String = NSLocalizedString(
            "content.no_provider_desc",
            comment: "Choose a provider from the sidebar"
        ),
        emptySystemImage: String = "sidebar.left",
        onTapTrailingAccessory: ((Tab) -> Void)? = nil
    ) {
        self.init(
            selectedTab: selectedTab,
            config: ProviderContentTabSidebarConfig(
                hasProviderSelection: hasProviderSelection,
                items: items,
                emptyState: ProviderContentTabSidebarEmptyStateConfig(
                    title: emptyTitle,
                    description: emptyDescription,
                    systemImage: emptySystemImage
                ),
                onTapTrailingAccessory: onTapTrailingAccessory
            )
        )
    }

    public var body: some View {
        SidebarColumnScaffold(
            title: Self.resolveHeaderTitle(hasProviderSelection: hasProviderSelection, emptyTitle: emptyTitle),
            showsHeader: false
        ) {
            Group {
                if hasProviderSelection {
                    List(selection: $selectedTab) {
                        ForEach(items) { item in
                            HStack {
                                Label(item.title, systemImage: item.iconName)
                                Spacer()

                                if let symbolName = item.trailingSymbolName {
                                    Button {
                                        onTapTrailingAccessory?(item.id)
                                    } label: {
                                        Image(systemName: symbolName)
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help(item.trailingHelpText ?? "")
                                }

                                if let countText = item.countText {
                                    Text(countText)
                                        .dsSecondaryText(font: .callout)
                                }
                            }
                            .tag(item.id)
                        }
                    }
                    .listStyle(.sidebar)
                } else {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: emptySystemImage,
                        description: Text(emptyDescription)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    )
                }
            }
        }
    }

    nonisolated static func resolveHeaderTitle(hasProviderSelection: Bool, emptyTitle: String) -> String {
        hasProviderSelection ? "" : emptyTitle
    }
}

public struct ProviderSidebarComponent: View {
    public struct Config {
        public var selectedItemKey: Binding<String?>
        public var sidebar: ProviderSidebarConfig
        public var actions: ProviderSidebarActionConfig

        public init(
            selectedItemKey: Binding<String?>,
            sidebar: ProviderSidebarConfig,
            actions: ProviderSidebarActionConfig
        ) {
            self.selectedItemKey = selectedItemKey
            self.sidebar = sidebar
            self.actions = actions
        }
    }

    @Binding private var selectedItemKey: String?

    private let sections: [SidebarSection]
    private let toolItems: [SidebarToolItem]
    private let style: ProviderSidebarStyle

    private let providerDebugLocatorText: (SidebarProviderItem) -> String?
    private let onShowInFinder: (SidebarProviderItem) -> Void
    private let onViewOfficialDocumentation: (SidebarProviderItem) -> Void
    private let onEdit: (SidebarProviderItem) -> Void
    private let onDeleteProvider: (SidebarProviderItem) -> Void
    private let onDeleteOffsets: (SidebarSection, IndexSet) -> Void
    private let onMove: (SidebarSection, IndexSet, Int) -> Void
    private let onAddProvider: () -> Void
    private let onCopyDebugMarker: (String) -> Void

    public init(config: Config) {
        self.init(
            selectedItemKey: config.selectedItemKey,
            config: config.sidebar,
            actions: config.actions
        )
    }

    public init(
        selectedItemKey: Binding<String?>,
        config: ProviderSidebarConfig,
        actions: ProviderSidebarActionConfig
    ) {
        self._selectedItemKey = selectedItemKey
        self.sections = config.sections
        self.toolItems = config.toolItems
        self.style = config.style
        self.providerDebugLocatorText = actions.providerDebugLocatorText
        self.onShowInFinder = actions.onShowInFinder
        self.onViewOfficialDocumentation = actions.onViewOfficialDocumentation
        self.onEdit = actions.onEdit
        self.onDeleteProvider = actions.onDeleteProvider
        self.onDeleteOffsets = actions.onDeleteOffsets
        self.onMove = actions.onMove
        self.onAddProvider = actions.onAddProvider
        self.onCopyDebugMarker = actions.onCopyDebugMarker
    }

    public init(
        selectedItemKey: Binding<String?>,
        sections: [SidebarSection],
        toolItems: [SidebarToolItem] = SidebarToolItem.default,
        style: ProviderSidebarStyle = .default,
        providerDebugLocatorText: @escaping (SidebarProviderItem) -> String? = { _ in nil },
        onShowInFinder: @escaping (SidebarProviderItem) -> Void,
        onViewOfficialDocumentation: @escaping (SidebarProviderItem) -> Void,
        onEdit: @escaping (SidebarProviderItem) -> Void,
        onDeleteProvider: @escaping (SidebarProviderItem) -> Void,
        onDeleteOffsets: @escaping (SidebarSection, IndexSet) -> Void,
        onMove: @escaping (SidebarSection, IndexSet, Int) -> Void,
        onAddProvider: @escaping () -> Void,
        onCopyDebugMarker: @escaping (String) -> Void = { _ in }
    ) {
        self.init(
            selectedItemKey: selectedItemKey,
            config: ProviderSidebarConfig(
                sections: sections,
                toolItems: toolItems,
                style: style
            ),
            actions: ProviderSidebarActionConfig(
                providerDebugLocatorText: providerDebugLocatorText,
                onShowInFinder: onShowInFinder,
                onViewOfficialDocumentation: onViewOfficialDocumentation,
                onEdit: onEdit,
                onDeleteProvider: onDeleteProvider,
                onDeleteOffsets: onDeleteOffsets,
                onMove: onMove,
                onAddProvider: onAddProvider,
                onCopyDebugMarker: onCopyDebugMarker
            )
        )
    }

    public var body: some View {
        List(selection: $selectedItemKey) {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        SidebarProviderRowView(
                            item: item,
                            style: style,
                            providerDebugLocatorText: providerDebugLocatorText,
                            onShowInFinder: onShowInFinder,
                            onViewOfficialDocumentation: onViewOfficialDocumentation,
                            onEdit: onEdit,
                            onDeleteProvider: onDeleteProvider,
                            onCopyDebugMarker: onCopyDebugMarker
                        )
                            .tag(SidebarSelectionKey.provider(item.id).rawValue)
                    }
                    .onDelete { offsets in
                        onDeleteOffsets(section, offsets)
                    }
                    .onMove { source, destination in
                        onMove(section, source, destination)
                    }
                } header: {
                    SidebarSectionHeaderView(
                        title: NSLocalizedString(
                            section.titleKey,
                            value: section.fallbackTitle,
                            comment: "Sidebar provider section title"
                        ),
                        style: style
                    )
                }
            }

            Section {
                ForEach(toolItems) { tool in
                    SidebarToolRowView(item: tool)
                }
            } header: {
                SidebarSectionHeaderView(
                    title: NSLocalizedString("sidebar.section.tools", value: "Tools", comment: "Sidebar tools section title"),
                    style: style
                )
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(NSLocalizedString("app.title", value: "nolon", comment: "App title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onAddProvider()
                } label: {
                    Label(
                        NSLocalizedString("action.add_provider", value: "Add Provider", comment: "Add provider action"),
                        systemImage: "plus"
                    )
                }
            }
        }
    }
}

public struct ProviderSidebarConfig {
    public var sections: [SidebarSection]
    public var toolItems: [SidebarToolItem]
    public var style: ProviderSidebarStyle

    public init(
        sections: [SidebarSection],
        toolItems: [SidebarToolItem] = SidebarToolItem.default,
        style: ProviderSidebarStyle = .default
    ) {
        self.sections = sections
        self.toolItems = toolItems
        self.style = style
    }
}

public struct ProviderSidebarActionConfig {
    public var providerDebugLocatorText: (SidebarProviderItem) -> String?
    public var onShowInFinder: (SidebarProviderItem) -> Void
    public var onViewOfficialDocumentation: (SidebarProviderItem) -> Void
    public var onEdit: (SidebarProviderItem) -> Void
    public var onDeleteProvider: (SidebarProviderItem) -> Void
    public var onDeleteOffsets: (SidebarSection, IndexSet) -> Void
    public var onMove: (SidebarSection, IndexSet, Int) -> Void
    public var onAddProvider: () -> Void
    public var onCopyDebugMarker: (String) -> Void

    public init(
        providerDebugLocatorText: @escaping (SidebarProviderItem) -> String? = { _ in nil },
        onShowInFinder: @escaping (SidebarProviderItem) -> Void,
        onViewOfficialDocumentation: @escaping (SidebarProviderItem) -> Void,
        onEdit: @escaping (SidebarProviderItem) -> Void,
        onDeleteProvider: @escaping (SidebarProviderItem) -> Void,
        onDeleteOffsets: @escaping (SidebarSection, IndexSet) -> Void,
        onMove: @escaping (SidebarSection, IndexSet, Int) -> Void,
        onAddProvider: @escaping () -> Void,
        onCopyDebugMarker: @escaping (String) -> Void = { _ in }
    ) {
        self.providerDebugLocatorText = providerDebugLocatorText
        self.onShowInFinder = onShowInFinder
        self.onViewOfficialDocumentation = onViewOfficialDocumentation
        self.onEdit = onEdit
        self.onDeleteProvider = onDeleteProvider
        self.onDeleteOffsets = onDeleteOffsets
        self.onMove = onMove
        self.onAddProvider = onAddProvider
        self.onCopyDebugMarker = onCopyDebugMarker
    }
}

struct SidebarProviderRowView: View {
    @State private var viewModel = SidebarProviderRowViewViewModel()
    @Environment(\.sidebarRowSize) private var sidebarRowSize

    let item: SidebarProviderItem
    let style: ProviderSidebarStyle
    let providerDebugLocatorText: (SidebarProviderItem) -> String?
    let onShowInFinder: (SidebarProviderItem) -> Void
    let onViewOfficialDocumentation: (SidebarProviderItem) -> Void
    let onEdit: (SidebarProviderItem) -> Void
    let onDeleteProvider: (SidebarProviderItem) -> Void
    let onCopyDebugMarker: (String) -> Void

    private var rowMetrics: SidebarProviderRowMetrics {
        SidebarProviderRowMetrics(sidebarRowSize: sidebarRowSize)
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: rowMetrics.textSpacing) {
                Text(item.title)
                    .font(rowMetrics.titleFont)
                if rowMetrics.showsSubtitle {
                    Text(item.subtitle)
                        .font(rowMetrics.subtitleFont)
                        .foregroundStyle(style.subtitleColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        } icon: {
            Image(systemName: item.iconName.isEmpty ? "folder" : item.iconName)
                .font(.system(size: rowMetrics.iconFontSize, weight: .semibold))
                .frame(width: rowMetrics.iconFrameSize, height: rowMetrics.iconFrameSize)
        }
        .padding(.vertical, rowMetrics.verticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            if item.hasDocumentation {
                Button {
                    onViewOfficialDocumentation(item)
                } label: {
                    Label(
                        NSLocalizedString("action.view_official_docs", value: "View Official Documentation", comment: "Open official provider documentation"),
                        systemImage: "book.closed"
                    )
                }

                Divider()
            }

            Button {
                onShowInFinder(item)
            } label: {
                Label(NSLocalizedString("action.show_in_finder", value: "Show in Finder", comment: "Show in Finder"), systemImage: "folder")
            }

            Button {
                onEdit(item)
            } label: {
                Label(NSLocalizedString("action.edit", value: "Edit", comment: "Edit"), systemImage: "square.and.pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDeleteProvider(item)
            } label: {
                Label(NSLocalizedString("action.delete", value: "Delete", comment: "Delete"), systemImage: "trash")
                    .foregroundStyle(style.destructiveColor)
            }

            if let locator = providerDebugLocatorText(item), !locator.isEmpty {
                Divider()

                Button {
                    onCopyDebugMarker(locator)
                } label: {
                    Label(
                        NSLocalizedString("debug.page_marker.copy", value: "Copy Page Marker", comment: "Copy sidebar row page marker"),
                        systemImage: "scope"
                    )
                }
            }
        }
    }
}

struct SidebarProviderRowMetrics {
    let titleFont: Font
    let subtitleFont: Font
    let iconFontSize: CGFloat
    let iconFrameSize: CGFloat
    let textSpacing: CGFloat
    let verticalPadding: CGFloat
    let showsSubtitle: Bool

    init(sidebarRowSize: SidebarRowSize) {
        switch sidebarRowSize {
        case .small:
            titleFont = DesignSystem.Typography.labelSmall
            subtitleFont = DesignSystem.Typography.caption2
            iconFontSize = 12
            iconFrameSize = 14
            textSpacing = 1
            verticalPadding = 1
            showsSubtitle = false
        case .medium:
            titleFont = DesignSystem.Typography.body
            subtitleFont = DesignSystem.Typography.caption2
            iconFontSize = 16
            iconFrameSize = 18
            textSpacing = 2
            verticalPadding = 2
            showsSubtitle = true
        case .large:
            titleFont = DesignSystem.Typography.bodyLarge
            subtitleFont = DesignSystem.Typography.bodySmall
            iconFontSize = 18
            iconFrameSize = 20
            textSpacing = 3
            verticalPadding = 3
            showsSubtitle = true
        @unknown default:
            titleFont = DesignSystem.Typography.body
            subtitleFont = DesignSystem.Typography.caption2
            iconFontSize = 16
            iconFrameSize = 18
            textSpacing = 2
            verticalPadding = 2
            showsSubtitle = true
        }
    }
}

struct SidebarSectionHeaderView: View {
    @State private var viewModel = SidebarSectionHeaderViewViewModel()
    let title: String
    let style: ProviderSidebarStyle

    var body: some View {
        Text(title)
            .font(DesignSystem.Typography.labelSmall)
            .foregroundStyle(style.headerColor)
    }
}

struct SidebarToolRowView: View {
    @State private var viewModel = SidebarToolRowViewViewModel()
    let item: SidebarToolItem

    var body: some View {
        Label(
            NSLocalizedString(item.titleKey, value: item.fallbackTitle, comment: "Sidebar tool item"),
            systemImage: item.systemImage
        )
        .tag(SidebarSelectionKey(rawValue: item.id.rawValue).rawValue)
    }
}
