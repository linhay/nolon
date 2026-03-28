import SwiftUI
import NolonUIFoundation

public typealias ResourceCenterCloseButtonMetrics = FloatingCloseButtonMetrics

public struct ResourceCenterCloseButton: View {
    public struct Config {
        public var help: String
        public var enableCancelShortcut: Bool
        public var action: () -> Void

        public init(
            help: String = "Close",
            enableCancelShortcut: Bool = true,
            action: @escaping () -> Void
        ) {
            self.help = help
            self.enableCancelShortcut = enableCancelShortcut
            self.action = action
        }
    }

    @State private var viewModel = ResourceCenterCloseButtonViewModel()
    private let help: String
    private let enableCancelShortcut: Bool
    private let action: () -> Void

    public init(config: Config) {
        self.help = config.help
        self.enableCancelShortcut = config.enableCancelShortcut
        self.action = config.action
    }

    public init(
        help: String = "Close",
        enableCancelShortcut: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(config: Config(help: help, enableCancelShortcut: enableCancelShortcut, action: action))
    }

    public var body: some View {
        FloatingCloseButton(
            help: help,
            enableCancelShortcut: enableCancelShortcut,
            action: action
        )
    }
}

public struct ResourceCenterImportWarningOverlay: View {
    public struct Config {
        public var message: String
        public var onDismiss: () -> Void

        public init(
            message: String,
            onDismiss: @escaping () -> Void
        ) {
            self.message = message
            self.onDismiss = onDismiss
        }
    }

    let message: String
    let onDismiss: () -> Void

    public init(config: Config) {
        self.message = config.message
        self.onDismiss = config.onDismiss
    }

    public init(message: String, onDismiss: @escaping () -> Void) {
        self.init(config: Config(message: message, onDismiss: onDismiss))
    }

    public var body: some View {
        DismissibleWarningBannerView(message: message, onDismiss: onDismiss)
            .padding(.horizontal, 16)
            .padding(.top, 10)
    }
}

public struct ResourceCenterUITestActionsOverlay: View {
    public struct Config {
        public var actions: [ResourceCenterUITestActionData]
        public var onTapAction: (ResourceCenterUITestActionData) -> Void

        public init(
            actions: [ResourceCenterUITestActionData],
            onTapAction: @escaping (ResourceCenterUITestActionData) -> Void
        ) {
            self.actions = actions
            self.onTapAction = onTapAction
        }
    }

    let actions: [ResourceCenterUITestActionData]
    let onTapAction: (ResourceCenterUITestActionData) -> Void

    public init(config: Config) {
        self.actions = config.actions
        self.onTapAction = config.onTapAction
    }

    public init(
        actions: [ResourceCenterUITestActionData],
        onTapAction: @escaping (ResourceCenterUITestActionData) -> Void
    ) {
        self.init(config: Config(actions: actions, onTapAction: onTapAction))
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(actions) { action in
                Button(action.title) {
                    onTapAction(action)
                }
                .accessibilityIdentifier(action.accessibilityIdentifier)
            }
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 12)
        .padding(.trailing, 16)
    }
}

public struct ResourceCenterOverlayConfig {
    public var importErrorMessage: String?
    public var onDismissImportError: () -> Void
    public var uiTestActions: [ResourceCenterUITestActionData]
    public var onTapUITestAction: (ResourceCenterUITestActionData) -> Void

    public init(
        importErrorMessage: String? = nil,
        onDismissImportError: @escaping () -> Void = {},
        uiTestActions: [ResourceCenterUITestActionData] = [],
        onTapUITestAction: @escaping (ResourceCenterUITestActionData) -> Void = { _ in }
    ) {
        self.importErrorMessage = importErrorMessage
        self.onDismissImportError = onDismissImportError
        self.uiTestActions = uiTestActions
        self.onTapUITestAction = onTapUITestAction
    }
}

public extension View {
    func resourceCenterOverlays(_ config: ResourceCenterOverlayConfig) -> some View {
        resourceCenterOverlays(
            importErrorMessage: config.importErrorMessage,
            onDismissImportError: config.onDismissImportError,
            uiTestActions: config.uiTestActions,
            onTapUITestAction: config.onTapUITestAction
        )
    }

    func resourceCenterOverlays(
        importErrorMessage: String?,
        onDismissImportError: @escaping () -> Void,
        uiTestActions: [ResourceCenterUITestActionData],
        onTapUITestAction: @escaping (ResourceCenterUITestActionData) -> Void
    ) -> some View {
        self
            .overlay(alignment: .top) {
                if let message = importErrorMessage, !message.isEmpty {
                    ResourceCenterImportWarningOverlay(
                        message: message,
                        onDismiss: onDismissImportError
                    )
                }
            }
            .overlay(alignment: .topTrailing) {
                if !uiTestActions.isEmpty {
                    ResourceCenterUITestActionsOverlay(
                        actions: uiTestActions,
                        onTapAction: onTapUITestAction
                    )
                }
            }
    }
}

public enum ResourceCenterSidebarMetrics {
    public static let headerHeight: CGFloat = SidebarColumnMetrics.headerHeight
    public static let headerHorizontalPadding: CGFloat = SidebarColumnMetrics.headerHorizontalPadding
    public static let columnMinWidth: CGFloat = SidebarColumnMetrics.columnMinWidth
    public static let columnIdealWidth: CGFloat = SidebarColumnMetrics.columnIdealWidth
    public static let columnMaxWidth: CGFloat = SidebarColumnMetrics.columnMaxWidth
}

public struct ResourceCenterSidebarEmptyStateConfig {
    public var title: String
    public var description: String
    public var systemImage: String

    public init(
        title: String = NSLocalizedString(
            "content.no_repository",
            comment: "Select a Repository"
        ),
        description: String = NSLocalizedString(
            "content.no_repository_desc",
            comment: "Choose a repository from the sidebar"
        ),
        systemImage: String = "tray"
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
    }
}

public struct ResourceCenterSidebarConfig {
    public var title: String
    public var items: [ResourceCenterTabItem]
    public var showsEmptyState: Bool
    public var emptyState: ResourceCenterSidebarEmptyStateConfig

    public init(
        title: String = NSLocalizedString(
            "resource.center.title",
            value: "Resource Center",
            comment: "Resource center title"
        ),
        items: [ResourceCenterTabItem],
        showsEmptyState: Bool,
        emptyState: ResourceCenterSidebarEmptyStateConfig = ResourceCenterSidebarEmptyStateConfig()
    ) {
        self.title = title
        self.items = items
        self.showsEmptyState = showsEmptyState
        self.emptyState = emptyState
    }
}

public struct ResourceCenterSidebarComponent: View {
    public struct Config {
        public var selectedTab: Binding<ResourceCenterTabID?>
        public var sidebar: ResourceCenterSidebarConfig

        public init(
            selectedTab: Binding<ResourceCenterTabID?>,
            sidebar: ResourceCenterSidebarConfig
        ) {
            self.selectedTab = selectedTab
            self.sidebar = sidebar
        }
    }

    @Binding private var selectedTab: ResourceCenterTabID?

    private let title: String
    private let items: [ResourceCenterTabItem]
    private let showsEmptyState: Bool
    private let emptyTitle: String
    private let emptyDescription: String
    private let emptySystemImage: String

    public init(config: Config) {
        self.init(config: config.sidebar, selectedTab: config.selectedTab)
    }

    public init(
        config: ResourceCenterSidebarConfig,
        selectedTab: Binding<ResourceCenterTabID?>
    ) {
        self.title = config.title
        self._selectedTab = selectedTab
        self.items = config.items
        self.showsEmptyState = config.showsEmptyState
        self.emptyTitle = config.emptyState.title
        self.emptyDescription = config.emptyState.description
        self.emptySystemImage = config.emptyState.systemImage
    }

    public init(
        title: String? = nil,
        selectedTab: Binding<ResourceCenterTabID?>,
        items: [ResourceCenterTabItem],
        showsEmptyState: Bool,
        emptyTitle: String = NSLocalizedString(
            "content.no_repository",
            comment: "Select a Repository"
        ),
        emptyDescription: String = NSLocalizedString(
            "content.no_repository_desc",
            comment: "Choose a repository from the sidebar"
        ),
        emptySystemImage: String = "tray"
    ) {
        self.init(
            config: ResourceCenterSidebarConfig(
                title: title ?? NSLocalizedString(
                    "resource.center.title",
                    value: "Resource Center",
                    comment: "Resource center title"
                ),
                items: items,
                showsEmptyState: showsEmptyState,
                emptyState: ResourceCenterSidebarEmptyStateConfig(
                    title: emptyTitle,
                    description: emptyDescription,
                    systemImage: emptySystemImage
                )
            ),
            selectedTab: selectedTab
        )
    }

    public var body: some View {
        SidebarColumnScaffold(title: title, showsHeader: false) {
            if showsEmptyState {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptySystemImage,
                    description: Text(emptyDescription)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                )
            } else {
                List(selection: $selectedTab) {
                    ForEach(items) { item in
                        HStack {
                            Label(
                                NSLocalizedString(
                                    item.titleKey,
                                    value: item.fallbackTitle,
                                    comment: "Resource center tab title"
                                ),
                                systemImage: item.iconName
                            )
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                .font(.callout)
                        }
                        .tag(item.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}
