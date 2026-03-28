import Foundation
import NolonUIFoundation
import SwiftUI

// MARK: - UnifiedPageScaffolds


public struct CodexBinaryPageScaffold<Content: View>: View {
    let isSupported: Bool
    let isLoading: Bool
    let unsupportedTitle: String
    let unsupportedSystemImage: String
    let unsupportedDescription: String
    let checkingUpdatesText: String?
    let content: () -> Content

    public struct Config {
        public var isSupported: Bool
        public var isLoading: Bool
        public var unsupportedTitle: String
        public var unsupportedSystemImage: String
        public var unsupportedDescription: String
        public var checkingUpdatesText: String?

        public init(
            isSupported: Bool,
            isLoading: Bool,
            unsupportedTitle: String,
            unsupportedSystemImage: String,
            unsupportedDescription: String,
            checkingUpdatesText: String? = nil
        ) {
            self.isSupported = isSupported
            self.isLoading = isLoading
            self.unsupportedTitle = unsupportedTitle
            self.unsupportedSystemImage = unsupportedSystemImage
            self.unsupportedDescription = unsupportedDescription
            self.checkingUpdatesText = checkingUpdatesText
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isSupported = config.isSupported
        self.isLoading = config.isLoading
        self.unsupportedTitle = config.unsupportedTitle
        self.unsupportedSystemImage = config.unsupportedSystemImage
        self.unsupportedDescription = config.unsupportedDescription
        self.checkingUpdatesText = config.checkingUpdatesText
        self.content = content
    }

    public init(
        isSupported: Bool,
        isLoading: Bool,
        unsupportedTitle: String,
        unsupportedSystemImage: String,
        unsupportedDescription: String,
        checkingUpdatesText: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isSupported: isSupported,
                isLoading: isLoading,
                unsupportedTitle: unsupportedTitle,
                unsupportedSystemImage: unsupportedSystemImage,
                unsupportedDescription: unsupportedDescription,
                checkingUpdatesText: checkingUpdatesText
            ),
            content: content
        )
    }

    public var body: some View {
        Group {
            if !isSupported {
                EmptyStateScaffold(
                    isEmpty: true,
                    emptyTitle: unsupportedTitle,
                    emptySystemImage: unsupportedSystemImage,
                    emptyDescription: unsupportedDescription
                ) {
                    EmptyView()
                }
            } else if isLoading {
                CenteredLoadingIndicatorView()
            } else {
                content()
            }
        }
        .overlay(alignment: .top) {
            if let checkingUpdatesText, !checkingUpdatesText.isEmpty {
                TopLoadingStatusBannerView(text: checkingUpdatesText)
                    .padding(.top, 12)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }
}



public struct CodexAdvancedEditorScaffold<Content: View>: View {
    let title: String
    let content: () -> Content

    public struct Config {
        public var title: String

        public init(title: String) {
            self.title = title
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = config.title
        self.content = content
    }

    public init(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(title: title),
            content: content
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 680, minHeight: 420)
    }
}


public struct PluginManagementPageScaffold<Content: View>: View {
    let isChecking: Bool
    let hasPlugin: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let errorMessage: String?
    let content: () -> Content

    public struct Config {
        public var isChecking: Bool
        public var hasPlugin: Bool
        public var emptyTitle: String
        public var emptySystemImage: String
        public var emptyDescription: String
        public var errorMessage: String?

        public init(
            isChecking: Bool,
            hasPlugin: Bool,
            emptyTitle: String = NSLocalizedString("plugin.empty.title", value: "No Plugin", comment: "No plugin title"),
            emptySystemImage: String = "puzzlepiece",
            emptyDescription: String = NSLocalizedString("plugin.empty.desc", value: "No available plugins.", comment: "No plugin description"),
            errorMessage: String?
        ) {
            self.isChecking = isChecking
            self.hasPlugin = hasPlugin
            self.emptyTitle = emptyTitle
            self.emptySystemImage = emptySystemImage
            self.emptyDescription = emptyDescription
            self.errorMessage = errorMessage
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isChecking = config.isChecking
        self.hasPlugin = config.hasPlugin
        self.emptyTitle = config.emptyTitle
        self.emptySystemImage = config.emptySystemImage
        self.emptyDescription = config.emptyDescription
        self.errorMessage = config.errorMessage
        self.content = content
    }

    public init(
        isChecking: Bool,
        hasPlugin: Bool,
        emptyTitle: String = NSLocalizedString("plugin.empty.title", value: "No Plugin", comment: "No plugin title"),
        emptySystemImage: String = "puzzlepiece",
        emptyDescription: String = NSLocalizedString("plugin.empty.desc", value: "No available plugins.", comment: "No plugin description"),
        errorMessage: String?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isChecking: isChecking,
                hasPlugin: hasPlugin,
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription,
                errorMessage: errorMessage
            ),
            content: content
        )
    }

    public var body: some View {
        PaddedScrollContainer {
            VStack(alignment: .leading, spacing: 12) {
                if isChecking {
                    CenteredLoadingIndicatorView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                EmptyStateScaffold(
                    isEmpty: !hasPlugin && !isChecking,
                    emptyTitle: emptyTitle,
                    emptySystemImage: emptySystemImage,
                    emptyDescription: emptyDescription
                ) {
                    if hasPlugin {
                        content()
                    } else {
                        EmptyView()
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.callout)
                        .dsSecondaryText(font: .callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}


public struct SettingsSheetScaffoldView<Content: View>: View {
    let items: [SettingsSidebarItemData]
    @Binding var selectedID: String
    let onClose: () -> Void
    let content: () -> Content

    public struct Config {
        public var title: String
        public var items: [SettingsSidebarItemData]
        public var onClose: () -> Void

        public init(
            title: String = NSLocalizedString("settings.title", value: "Settings", comment: "Settings sheet title"),
            items: [SettingsSidebarItemData],
            onClose: @escaping () -> Void
        ) {
            self.title = title
            self.items = items
            self.onClose = onClose
        }
    }

    public init(
        selectedID: Binding<String>,
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.items = config.items
        self._selectedID = selectedID
        self.onClose = config.onClose
        self.content = content
    }

    public init(
        title: String = NSLocalizedString("settings.title", value: "Settings", comment: "Settings sheet title"),
        items: [SettingsSidebarItemData],
        selectedID: Binding<String>,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            selectedID: selectedID,
            config: Config(
                title: title,
                items: items,
                onClose: onClose
            ),
            content: content
        )
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            SplitLayoutScaffold(
                columnVisibility: .constant(.all),
                profile: SplitLayoutProfiles.settings
            ) {
                settingsSidebar
            } content: {
                EmptyView()
            } detail: {
                settingsDetail
            }

            FloatingCloseButton(
                help: "Close",
                enableCancelShortcut: true,
                action: onClose
            )
            .padding(SkillDetailScaffoldMetrics.closeButtonPadding)
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(DesignSystem.Colors.Background.canvas)
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                GenericSelectionControl(
                    value: item.id,
                    selection: $selectedID
                ) { isSelected in
                    Text(item.title)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS)
                                .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.08) : Color.clear)
                        )
                }
                .dsLinkButton()
            }
            Spacer()
        }
        .padding(.top, 56)
        .padding(.horizontal, 12)
        .background(DesignSystem.Colors.Component.controlFillSubtle.opacity(0.6))
    }

    private var settingsDetail: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    content()
                }
                .padding(.top, 56)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(DesignSystem.Colors.Background.surface)
    }
}


public struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    public struct Config {
        public var title: String

        public init(title: String) {
            self.title = title
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = config.title
        self.content = content
    }

    public init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(
            config: Config(title: title),
            content: content
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
            content()
        }
    }
}


// MARK: - UnifiedScaffoldViews


public struct EmptyStateScaffold<Content: View>: View {
    let isEmpty: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let content: () -> Content

    public struct Config {
        public var isEmpty: Bool
        public var emptyTitle: String
        public var emptySystemImage: String
        public var emptyDescription: String

        public init(
            isEmpty: Bool,
            emptyTitle: String,
            emptySystemImage: String,
            emptyDescription: String
        ) {
            self.isEmpty = isEmpty
            self.emptyTitle = emptyTitle
            self.emptySystemImage = emptySystemImage
            self.emptyDescription = emptyDescription
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = config.isEmpty
        self.emptyTitle = config.emptyTitle
        self.emptySystemImage = config.emptySystemImage
        self.emptyDescription = config.emptyDescription
        self.content = content
    }

    public init(
        isEmpty: Bool,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isEmpty: isEmpty,
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription
            ),
            content: content
        )
    }

    public var body: some View {
        if isEmpty {
            UnavailableStateView(
                title: emptyTitle,
                systemImage: emptySystemImage,
                description: emptyDescription
            )
        } else {
            content()
        }
    }
}


public struct ProviderEmptyStateScaffold<Content: View>: View {
    public enum Preset {
        case usageUnsupported
        case gatewayPickerEmpty

        public var emptyTitle: String {
            switch self {
            case .usageUnsupported:
                return NSLocalizedString(
                    "usage.monitor.unsupported.title",
                    value: "Usage not supported",
                    comment: "Unsupported title"
                )
            case .gatewayPickerEmpty:
                return NSLocalizedString(
                    "codex.gateway.accounts.picker.empty.title",
                    value: "没有可添加的账号",
                    comment: "Gateway account picker empty title"
                )
            }
        }

        public var emptySystemImage: String {
            switch self {
            case .usageUnsupported:
                return "chart.bar.xaxis"
            case .gatewayPickerEmpty:
                return "person.crop.circle.badge.checkmark"
            }
        }

        public var emptyDescription: String {
            switch self {
            case .usageUnsupported:
                return NSLocalizedString(
                    "usage.monitor.unsupported.desc",
                    value: "Usage is not configured for this provider yet.",
                    comment: "Unsupported description"
                )
            case .gatewayPickerEmpty:
                return NSLocalizedString(
                    "codex.gateway.accounts.picker.empty.desc",
                    value: "当前所有账号都已在此网关卡片中。",
                    comment: "Gateway account picker empty description"
                )
            }
        }
    }

    let isEmpty: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let content: () -> Content

    public struct Config {
        public var isEmpty: Bool
        public var emptyTitle: String
        public var emptySystemImage: String
        public var emptyDescription: String

        public init(
            isEmpty: Bool,
            emptyTitle: String,
            emptySystemImage: String,
            emptyDescription: String
        ) {
            self.isEmpty = isEmpty
            self.emptyTitle = emptyTitle
            self.emptySystemImage = emptySystemImage
            self.emptyDescription = emptyDescription
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = config.isEmpty
        self.emptyTitle = config.emptyTitle
        self.emptySystemImage = config.emptySystemImage
        self.emptyDescription = config.emptyDescription
        self.content = content
    }

    public init(
        isEmpty: Bool,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isEmpty: isEmpty,
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription
            ),
            content: content
        )
    }

    public init(
        isEmpty: Bool,
        preset: Preset,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isEmpty: isEmpty,
            emptyTitle: preset.emptyTitle,
            emptySystemImage: preset.emptySystemImage,
            emptyDescription: preset.emptyDescription,
            content: content
        )
    }

    public var body: some View {
        if isEmpty {
            ProviderGridEmptyStateView(
                title: emptyTitle,
                systemImage: emptySystemImage,
                description: emptyDescription
            )
        } else {
            content()
        }
    }
}


public struct WindowEmptyStateScaffold<Content: View>: View {
    let hasContent: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let minWidth: CGFloat
    let minHeight: CGFloat
    let content: () -> Content

    public struct Config {
        public var hasContent: Bool
        public var emptyTitle: String
        public var emptySystemImage: String
        public var emptyDescription: String
        public var minWidth: CGFloat
        public var minHeight: CGFloat

        public init(
            hasContent: Bool,
            emptyTitle: String,
            emptySystemImage: String,
            emptyDescription: String,
            minWidth: CGFloat,
            minHeight: CGFloat
        ) {
            self.hasContent = hasContent
            self.emptyTitle = emptyTitle
            self.emptySystemImage = emptySystemImage
            self.emptyDescription = emptyDescription
            self.minWidth = minWidth
            self.minHeight = minHeight
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.hasContent = config.hasContent
        self.emptyTitle = config.emptyTitle
        self.emptySystemImage = config.emptySystemImage
        self.emptyDescription = config.emptyDescription
        self.minWidth = config.minWidth
        self.minHeight = config.minHeight
        self.content = content
    }

    public init(
        hasContent: Bool,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        minWidth: CGFloat,
        minHeight: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                hasContent: hasContent,
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription,
                minWidth: minWidth,
                minHeight: minHeight
            ),
            content: content
        )
    }

    public static func resourceCenterEmptyState(
        hasContent: Bool,
        minWidth: CGFloat,
        minHeight: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> Self {
        Self(
            hasContent: hasContent,
            emptyTitle: NSLocalizedString(
                "resource.center.empty.title",
                value: "No Resource Center Context",
                comment: "Resource center empty title"
            ),
            emptySystemImage: "tray",
            emptyDescription: NSLocalizedString(
                "resource.center.empty.desc",
                value: "Open Resource Center from toolbar or provider view.",
                comment: "Resource center empty description"
            ),
            minWidth: minWidth,
            minHeight: minHeight,
            content: content
        )
    }

    public static func skillDetailEmptyState(
        hasContent: Bool,
        minWidth: CGFloat,
        minHeight: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> Self {
        Self(
            hasContent: hasContent,
            emptyTitle: NSLocalizedString(
                "detail.skill.empty.title",
                value: "No Skill Selected",
                comment: "Skill detail empty title"
            ),
            emptySystemImage: "doc.text.magnifyingglass",
            emptyDescription: NSLocalizedString(
                "detail.skill.empty.desc",
                value: "Select a skill to view details.",
                comment: "Skill detail empty description"
            ),
            minWidth: minWidth,
            minHeight: minHeight,
            content: content
        )
    }

    public var body: some View {
        EmptyStateScaffold(
            isEmpty: !hasContent,
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            emptyDescription: emptyDescription
        ) {
            if hasContent {
                content()
            } else {
                EmptyView()
            }
        }
        .frame(minWidth: minWidth, minHeight: minHeight)
    }
}


public struct ProviderTabScrollScaffold<Content: View>: View {
    let content: () -> Content

    public struct Config {
        public init() {}
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
    }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.init(
            config: Config(),
            content: content
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
        }
    }
}


public struct ProviderGridContentScaffold<Content: View>: View {
    let isEmpty: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let columns: [GridItem]
    let spacing: CGFloat
    let content: () -> Content

    public struct Config {
        public var isEmpty: Bool
        public var emptyTitle: String
        public var emptySystemImage: String
        public var emptyDescription: String
        public var columns: [GridItem]
        public var spacing: CGFloat

        public init(
            isEmpty: Bool,
            emptyTitle: String = NSLocalizedString("provider.empty", value: "No Skills", comment: "No skills"),
            emptySystemImage: String = "folder.badge.questionmark",
            emptyDescription: String = NSLocalizedString("provider.empty_desc", value: "No skills found in this provider", comment: "No skills in provider"),
            columns: [GridItem],
            spacing: CGFloat = 16
        ) {
            self.isEmpty = isEmpty
            self.emptyTitle = emptyTitle
            self.emptySystemImage = emptySystemImage
            self.emptyDescription = emptyDescription
            self.columns = columns
            self.spacing = spacing
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = config.isEmpty
        self.emptyTitle = config.emptyTitle
        self.emptySystemImage = config.emptySystemImage
        self.emptyDescription = config.emptyDescription
        self.columns = config.columns
        self.spacing = config.spacing
        self.content = content
    }

    public init(
        isEmpty: Bool,
        emptyTitle: String = NSLocalizedString("provider.empty", value: "No Skills", comment: "No skills"),
        emptySystemImage: String = "folder.badge.questionmark",
        emptyDescription: String = NSLocalizedString("provider.empty_desc", value: "No skills found in this provider", comment: "No skills in provider"),
        columns: [GridItem],
        spacing: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isEmpty: isEmpty,
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription,
                columns: columns,
                spacing: spacing
            ),
            content: content
        )
    }

    public var body: some View {
        if isEmpty {
            ProviderGridEmptyStateView(
                title: emptyTitle,
                systemImage: emptySystemImage,
                description: emptyDescription
            )
        } else {
            LazyVGrid(columns: columns, spacing: spacing) {
                content()
            }
        }
    }
}


public struct NavigationTopContentScaffold<Top: View, Content: View>: View {
    let navigationTitle: String
    let top: () -> Top
    let content: () -> Content

    public struct Config {
        public var navigationTitle: String

        public init(
            navigationTitle: String = NSLocalizedString("provider.title", value: "Provider Skills", comment: "Provider skills title")
        ) {
            self.navigationTitle = navigationTitle
        }
    }

    public init(
        config: Config,
        @ViewBuilder top: @escaping () -> Top,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.navigationTitle = config.navigationTitle
        self.top = top
        self.content = content
    }

    public init(
        navigationTitle: String = NSLocalizedString("provider.title", value: "Provider Skills", comment: "Provider skills title"),
        @ViewBuilder top: @escaping () -> Top,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(navigationTitle: navigationTitle),
            top: top,
            content: content
        )
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                top()
                content()
            }
            .navigationTitle(navigationTitle)
        }
    }
}


public struct SidebarHeaderScaffold<Content: View>: View {
    let showsSheetHeader: Bool
    let sheetTitle: String
    let sidebarTitle: String?
    let content: () -> Content

    public struct Config {
        public var showsSheetHeader: Bool
        public var sheetTitle: String
        public var sidebarTitle: String?

        public init(
            showsSheetHeader: Bool,
            sheetTitle: String,
            sidebarTitle: String? = nil
        ) {
            self.showsSheetHeader = showsSheetHeader
            self.sheetTitle = sheetTitle
            self.sidebarTitle = sidebarTitle
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showsSheetHeader = config.showsSheetHeader
        self.sheetTitle = config.sheetTitle
        self.sidebarTitle = config.sidebarTitle
        self.content = content
    }

    public init(
        showsSheetHeader: Bool,
        sheetTitle: String,
        sidebarTitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                showsSheetHeader: showsSheetHeader,
                sheetTitle: sheetTitle,
                sidebarTitle: sidebarTitle
            ),
            content: content
        )
    }

    public var body: some View {
        if showsSheetHeader {
            SheetHeaderSection(title: sheetTitle) {
                EmptyView()
            } content: {
                content()
            }
        } else if let sidebarTitle, !sidebarTitle.isEmpty {
            VStack(spacing: 0) {
                SidebarTitleHeaderRowView(title: sidebarTitle)
                content()
            }
        } else {
            content()
        }
    }
}


// MARK: - UnifiedSheetScaffoldViews

public enum SheetLayout {
    public static let horizontalPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let contentVerticalPadding: CGFloat = DesignSystem.Metrics.paddingL
    public static let contentBottomPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let footerHorizontalPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let footerVerticalPadding: CGFloat = DesignSystem.Metrics.paddingL
}

public struct SheetDivider: View {
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
        Divider()
            .background(DesignSystem.Colors.Component.separator.opacity(0.25))
    }
}

public extension View {
    @ViewBuilder
    func sheetScrollContentPadding() -> some View {
        self
            .padding(.horizontal, SheetLayout.horizontalPadding)
            .padding(.top, SheetLayout.contentVerticalPadding)
            .padding(.bottom, SheetLayout.contentBottomPadding)
    }
}

public enum SheetHeaderMetrics {
    public static let horizontalPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let topPadding: CGFloat = DesignSystem.Metrics.paddingXL
    public static let bottomPadding: CGFloat = DesignSystem.Metrics.paddingL
}

public struct SheetHeaderView<Trailing: View>: View {
    @State private var viewModel = SheetHeaderViewViewModel()
    private let title: String
    private var subtitle: String?
    private var isCloseDisabled = false
    private var onClose: (() -> Void)?
    private var trailing: Trailing?

    public struct Config {
        public var title: String
        public var subtitle: String?
        public var isCloseDisabled: Bool
        public var onClose: (() -> Void)?

        public init(
            title: String,
            subtitle: String? = nil,
            isCloseDisabled: Bool = false,
            onClose: (() -> Void)? = nil
        ) {
            self.title = title
            self.subtitle = subtitle
            self.isCloseDisabled = isCloseDisabled
            self.onClose = onClose
        }
    }

    public init(
        config: Config,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = config.title
        self.subtitle = config.subtitle
        self.trailing = trailing()
    }

    public init(
        config: Config
    ) where Trailing == EmptyView {
        self.title = config.title
        self.subtitle = config.subtitle
        self.isCloseDisabled = config.isCloseDisabled
        self.onClose = config.onClose
        self.trailing = nil
    }

    public init(
        title: String,
        subtitle: String? = nil,
        isCloseDisabled: Bool = false,
        onClose: @escaping () -> Void
    ) where Trailing == EmptyView {
        self.init(
            config: Config(
                title: title,
                subtitle: subtitle,
                isCloseDisabled: isCloseDisabled,
                onClose: onClose
            )
        )
    }

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            config: Config(
                title: title,
                subtitle: subtitle
            ),
            trailing: trailing
        )
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Metrics.spacingL) {
            VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingXS) {
                Text(title)
                    .font(DesignSystem.Typography.h3)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .dsSecondaryText(font: .subheadline)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
            if let trailing {
                trailing
            } else if let onClose {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .dsIconButton(size: 24, foreground: DesignSystem.Colors.Text.tertiary)
                }
                .accessibilityLabel(NSLocalizedString("Close", comment: "Close"))
                .dsLinkButton()
                .disabled(isCloseDisabled)
            }
        }
        .padding(.horizontal, SheetHeaderMetrics.horizontalPadding)
        .padding(.top, SheetHeaderMetrics.topPadding)
        .padding(.bottom, SheetHeaderMetrics.bottomPadding)
    }
}

public struct SheetHeaderSection<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: () -> Trailing
    let content: () -> Content

    public struct Config {
        public var title: String
        public var subtitle: String?

        public init(
            title: String,
            subtitle: String? = nil
        ) {
            self.title = title
            self.subtitle = subtitle
        }
    }

    public init(
        config: Config,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = config.title
        self.subtitle = config.subtitle
        self.trailing = trailing
        self.content = content
    }

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                title: title,
                subtitle: subtitle
            ),
            trailing: trailing,
            content: content
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: title, subtitle: subtitle, trailing: trailing)
            SheetDivider()
            content()
        }
    }
}

public struct SheetHeaderFooterScaffold<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String?
    let isCloseDisabled: Bool
    let onClose: () -> Void
    let content: () -> Content
    let footer: () -> Footer

    public struct Config {
        public var title: String
        public var subtitle: String?
        public var isCloseDisabled: Bool
        public var onClose: () -> Void

        public init(
            title: String,
            subtitle: String? = nil,
            isCloseDisabled: Bool = false,
            onClose: @escaping () -> Void
        ) {
            self.title = title
            self.subtitle = subtitle
            self.isCloseDisabled = isCloseDisabled
            self.onClose = onClose
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.title = config.title
        self.subtitle = config.subtitle
        self.isCloseDisabled = config.isCloseDisabled
        self.onClose = config.onClose
        self.content = content
        self.footer = footer
    }

    public init(
        title: String,
        subtitle: String? = nil,
        isCloseDisabled: Bool = false,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(
            config: Config(
                title: title,
                subtitle: subtitle,
                isCloseDisabled: isCloseDisabled,
                onClose: onClose
            ),
            content: content,
            footer: footer
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: title,
                subtitle: subtitle,
                isCloseDisabled: isCloseDisabled,
                onClose: onClose
            )

            SheetDivider()

            content()

            SheetDivider()

            footer()
        }
    }
}

public struct SheetActionFooterView: View {
    let cancelTitle: String
    let primaryTitle: String
    let isPrimaryDisabled: Bool
    let onCancel: () -> Void
    let onPrimary: () -> Void

    public struct Config {
        public var cancelTitle: String
        public var primaryTitle: String
        public var isPrimaryDisabled: Bool
        public var onCancel: () -> Void
        public var onPrimary: () -> Void

        public init(
            cancelTitle: String = NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"),
            primaryTitle: String,
            isPrimaryDisabled: Bool = false,
            onCancel: @escaping () -> Void,
            onPrimary: @escaping () -> Void
        ) {
            self.cancelTitle = cancelTitle
            self.primaryTitle = primaryTitle
            self.isPrimaryDisabled = isPrimaryDisabled
            self.onCancel = onCancel
            self.onPrimary = onPrimary
        }
    }

    public init(
        config: Config
    ) {
        self.cancelTitle = config.cancelTitle
        self.primaryTitle = config.primaryTitle
        self.isPrimaryDisabled = config.isPrimaryDisabled
        self.onCancel = config.onCancel
        self.onPrimary = config.onPrimary
    }

    public init(
        cancelTitle: String = NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"),
        primaryTitle: String,
        isPrimaryDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                cancelTitle: cancelTitle,
                primaryTitle: primaryTitle,
                isPrimaryDisabled: isPrimaryDisabled,
                onCancel: onCancel,
                onPrimary: onPrimary
            )
        )
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button(cancelTitle) {
                onCancel()
            }
            .dsLinkButton()

            Spacer(minLength: 0)

            Button(primaryTitle) {
                onPrimary()
            }
            .dsPrimaryButton()
            .disabled(isPrimaryDisabled)
        }
        .padding(.horizontal, SheetLayout.footerHorizontalPadding)
        .padding(.vertical, SheetLayout.footerVerticalPadding)
    }
}

public struct SheetPaddedList<Data: RandomAccessCollection, RowContent: View>: View where Data.Element: Identifiable {
    public struct Config {
        public var data: Data

        public init(data: Data) {
            self.data = data
        }
    }

    let data: Data
    let rowContent: (Data.Element) -> RowContent

    public init(
        config: Config,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.data = config.data
        self.rowContent = rowContent
    }

    public init(
        _ data: Data,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.init(config: Config(data: data), rowContent: rowContent)
    }

    public var body: some View {
        List(data) { item in
            rowContent(item)
        }
        .sheetScrollContentPadding()
    }
}

// MARK: - UnifiedSlotCardView

enum UnifiedCardContainerStyle {
    case provider(isSelected: Bool)
    case resource(isSelected: Bool)
}

struct UnifiedSlotCardView<Header: View, Body: View, Meta: View, Actions: View, MenuContent: View>: View {
    @State private var isHovered = false

    let minHeight: CGFloat
    let contentPadding: CGFloat
    let style: UnifiedCardContainerStyle
    let onTap: (() -> Void)?
    let spacing: CGFloat
    let showsInlineMenuButton: Bool
    let showsBody: Bool
    let showsMeta: Bool
    let showsDividerBeforeActions: Bool
    let showsActions: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let bodyContent: () -> Body
    @ViewBuilder let metaContent: () -> Meta
    @ViewBuilder let actionContent: () -> Actions
    @ViewBuilder let menuContent: () -> MenuContent

    init(
        minHeight: CGFloat,
        contentPadding: CGFloat,
        style: UnifiedCardContainerStyle,
        onTap: (() -> Void)? = nil,
        spacing: CGFloat = DesignSystem.Metrics.spacingM,
        showsInlineMenuButton: Bool = false,
        showsBody: Bool = true,
        showsMeta: Bool = false,
        showsDividerBeforeActions: Bool = false,
        showsActions: Bool = false,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder bodyContent: @escaping () -> Body,
        @ViewBuilder metaContent: @escaping () -> Meta,
        @ViewBuilder actionContent: @escaping () -> Actions,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self.minHeight = minHeight
        self.contentPadding = contentPadding
        self.style = style
        self.onTap = onTap
        self.spacing = spacing
        self.showsInlineMenuButton = showsInlineMenuButton
        self.showsBody = showsBody
        self.showsMeta = showsMeta
        self.showsDividerBeforeActions = showsDividerBeforeActions
        self.showsActions = showsActions
        self.header = header
        self.bodyContent = bodyContent
        self.metaContent = metaContent
        self.actionContent = actionContent
        self.menuContent = menuContent
    }

    @ViewBuilder
    var body: some View {
        let wrapped = styledContent()
            .contentShape(Rectangle())
            .contextMenu {
                menuContent()
            }

        if let onTap {
            wrapped.onTapGesture(perform: onTap)
        } else {
            wrapped
        }
    }

    @ViewBuilder
    private func styledContent() -> some View {
        switch style {
        case let .provider(isSelected):
            VStack(alignment: .leading, spacing: spacing) {
                headerSection

                if showsBody {
                    bodyContent()
                }

                if showsMeta {
                    metaContent()
                }

                if showsDividerBeforeActions {
                    Divider()
                }

                if showsActions {
                    actionContent()
                }
            }
            .padding(contentPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .providerTabCardStyle(isSelected: isSelected)

        case let .resource(isSelected):
            VStack(alignment: .leading, spacing: spacing) {
                headerSection

                if showsBody {
                    bodyContent()
                }

                if showsMeta {
                    metaContent()
                }

                if showsDividerBeforeActions {
                    Divider()
                }

                if showsActions {
                    actionContent()
                }
            }
            .padding(contentPadding)
            .frame(minHeight: minHeight)
            .dsCard(
                background: isSelected
                    ? DesignSystem.Colors.primary.opacity(0.10)
                    : DesignSystem.Colors.Background.elevated,
                borderColor: isSelected
                    ? DesignSystem.Colors.primary
                    : (isHovered
                        ? DesignSystem.Colors.primary.opacity(0.24)
                        : DesignSystem.Colors.Component.border.opacity(0.60)),
                borderWidth: isSelected ? 2 : 1
            )
            .shadow(
                color: DesignSystem.Colors.Shadow.floating.opacity(isHovered ? 0.28 : 0.18),
                radius: isHovered ? 12 : 7,
                y: isHovered ? 6 : 3
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        if showsInlineMenuButton {
            HStack(alignment: .center, spacing: DesignSystem.Metrics.spacingS) {
                header()
                Spacer()
                EllipsisMenuButton(content: { menuContent() })
            }
        } else {
            header()
        }
    }
}
