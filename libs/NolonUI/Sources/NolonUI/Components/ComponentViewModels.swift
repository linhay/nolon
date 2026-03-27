import Observation
import SwiftUI
import NolonUIFoundation

// Auto-generated baseline view models for NolonUI components.
@Observable
public final class AccountListModeModuleViewModel {
    public init() {}
}

@Observable
public final class AccountQuotaModuleViewModel {
    public init() {}
}

@Observable
public final class AccountInlineQuotaProgressViewModel {
    public init() {}
}

@Observable
public final class AccountErrorStateModuleViewModel {
    public init() {}
}

@Observable
public final class AccountLoadingStateModuleViewModel {
    public init() {}
}

@Observable
public final class AccountEmptyStateModuleViewModel {
    public init() {}
}

@Observable
public final class AccountSummaryCardViewModel {
    public init() {}
}

@Observable
public final class AccountSummaryContentCardViewModel {
    public init() {}
}

@Observable
public final class AccountUsageChartModuleViewModel {
    public init() {}
}

@Observable
public final class AccountUsageMetricRowViewModel {
    public init() {}
}

@Observable
public final class AccountUsageContentCardViewModel {
    public init() {}
}

@Observable
public final class AccountUsageContentCardSceneViewModel {
    public init() {}
}

@Observable
public final class GatewayCardListModuleViewModel {
    public init() {}
}

@Observable
public final class GatewayCardModuleViewModel {
    public init() {}
}

@Observable
public final class GenericSelectionControlViewModel {
    public init() {}
}

@Observable
public final class ProviderUsageEmptyStateCardViewModel {
    public var title: LocalizedStringKey
    public var systemImage: String
    public var descriptionText: Text

    public init(title: LocalizedStringKey, systemImage: String, descriptionText: Text) {
        self.title = title
        self.systemImage = systemImage
        self.descriptionText = descriptionText
    }
}

@Observable
public final class SkillDetailScaffoldViewModel {
    public var columnVisibility: NavigationSplitViewVisibility

    public init(columnVisibility: NavigationSplitViewVisibility = .all) {
        self.columnVisibility = columnVisibility
    }
}

@Observable
public final class SkillDetailSidebarContainerViewModel {
    public init() {}
}

@Observable
public final class LiquidBackgroundViewModel {
    public var appear: Bool

    public init(appear: Bool = false) {
        self.appear = appear
    }

    public func startAnimation() {
        withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
            appear.toggle()
        }
    }
}

@Observable
public final class OnboardingWelcomeViewViewModel {
    public struct FeatureItem: Identifiable {
        public let id: String
        public let icon: String
        public let titleKey: LocalizedStringKey
        public let descriptionKey: LocalizedStringKey
        public let color: Color

        public init(
            id: String,
            icon: String,
            titleKey: LocalizedStringKey,
            descriptionKey: LocalizedStringKey,
            color: Color
        ) {
            self.id = id
            self.icon = icon
            self.titleKey = titleKey
            self.descriptionKey = descriptionKey
            self.color = color
        }
    }

    public let appIcon: Image
    public var titleKey: LocalizedStringKey
    public var subtitleKey: LocalizedStringKey
    public var featureItems: [FeatureItem]

    public init(
        appIcon: Image,
        titleKey: LocalizedStringKey = "onboarding.welcome.title",
        subtitleKey: LocalizedStringKey = "onboarding.welcome.subtitle",
        featureItems: [FeatureItem] = [
            .init(
                id: "unified",
                icon: "brain.head.profile",
                titleKey: "onboarding.feature.unified.title",
                descriptionKey: "onboarding.feature.unified.description",
                color: DesignSystem.Colors.primary
            ),
            .init(
                id: "github",
                icon: "link.circle.fill",
                titleKey: "onboarding.feature.github.title",
                descriptionKey: "onboarding.feature.github.description",
                color: DesignSystem.Colors.primary
            ),
            .init(
                id: "clawdhub",
                icon: "cloud.fill",
                titleKey: "onboarding.feature.clawdhub.title",
                descriptionKey: "onboarding.feature.clawdhub.description",
                color: DesignSystem.Colors.primary
            )
        ]
    ) {
        self.appIcon = appIcon
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.featureItems = featureItems
    }
}

@Observable
public final class OnboardingCompletionViewViewModel {
    public struct ProviderItem: Identifiable {
        public let id: String
        public let name: String
        public let logoName: String?

        public init(id: String, name: String, logoName: String? = nil) {
            self.id = id
            self.name = name
            self.logoName = logoName
        }
    }

    public struct TipItem: Identifiable {
        public let id: String
        public let icon: String
        public let textKey: LocalizedStringKey

        public init(id: String, icon: String, textKey: LocalizedStringKey) {
            self.id = id
            self.icon = icon
            self.textKey = textKey
        }
    }

    public var titleKey: LocalizedStringKey
    public var subtitleKey: LocalizedStringKey
    public var tipsTitleKey: LocalizedStringKey
    public var providers: [ProviderItem]
    public var avatarLimit: Int
    public var tips: [TipItem]

    public init(
        titleKey: LocalizedStringKey = "onboarding.completion.title",
        subtitleKey: LocalizedStringKey = "onboarding.completion.subtitle",
        tipsTitleKey: LocalizedStringKey = "onboarding.completion.tips_title",
        providers: [ProviderItem],
        avatarLimit: Int = 8,
        tips: [TipItem] = [
            .init(id: "add-provider", icon: "plus", textKey: "onboarding.completion.tip_add_provider"),
            .init(id: "clawdhub", icon: "cloud", textKey: "onboarding.completion.tip_clawdhub")
        ]
    ) {
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.tipsTitleKey = tipsTitleKey
        self.providers = providers
        self.avatarLimit = avatarLimit
        self.tips = tips
    }
}

@Observable
public final class OnboardingProviderSelectionViewViewModel {
    public struct ProviderItem: Identifiable {
        public let id: String
        public let name: String
        public let logoName: String?

        public init(id: String, name: String, logoName: String?) {
            self.id = id
            self.name = name
            self.logoName = logoName
        }
    }

    public struct Section: Identifiable {
        public let id: String
        public let title: String
        public let providers: [ProviderItem]

        public init(id: String, title: String, providers: [ProviderItem]) {
            self.id = id
            self.title = title
            self.providers = providers
        }
    }

    public var titleKey: LocalizedStringKey
    public var subtitleKey: LocalizedStringKey
    public var sections: [Section]
    public var selectedProviderIDs: Set<String>
    public var detectedProviderIDs: Set<String>

    private let onToggleProvider: (String) -> Void

    public init(
        titleKey: LocalizedStringKey = "onboarding.provider.title",
        subtitleKey: LocalizedStringKey = "onboarding.provider.subtitle",
        sections: [Section],
        selectedProviderIDs: Set<String>,
        detectedProviderIDs: Set<String>,
        onToggleProvider: @escaping (String) -> Void
    ) {
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.sections = sections
        self.selectedProviderIDs = selectedProviderIDs
        self.detectedProviderIDs = detectedProviderIDs
        self.onToggleProvider = onToggleProvider
    }

    public func isSelected(id: String) -> Bool {
        selectedProviderIDs.contains(id)
    }

    public func isDetected(id: String) -> Bool {
        detectedProviderIDs.contains(id)
    }

    public func toggleSelection(id: String) {
        onToggleProvider(id)
    }
}

@Observable
public final class SkillDetailViewViewModel {
    public var viewData: SkillDetailViewData
    private let onClose: () -> Void
    private let onSelectFile: (String) -> Void
    private let onInstallProvider: (String) -> Void
    private let onToggleWorkflow: (String) -> Void
    private let onRevealInFinder: () -> Void
    private let onOpenMarkdownLink: (URL) -> OpenURLAction.Result

    public init(
        viewData: SkillDetailViewData,
        onClose: @escaping () -> Void,
        onSelectFile: @escaping (String) -> Void,
        onInstallProvider: @escaping (String) -> Void,
        onToggleWorkflow: @escaping (String) -> Void,
        onRevealInFinder: @escaping () -> Void,
        onOpenMarkdownLink: @escaping (URL) -> OpenURLAction.Result
    ) {
        self.viewData = viewData
        self.onClose = onClose
        self.onSelectFile = onSelectFile
        self.onInstallProvider = onInstallProvider
        self.onToggleWorkflow = onToggleWorkflow
        self.onRevealInFinder = onRevealInFinder
        self.onOpenMarkdownLink = onOpenMarkdownLink
    }

    public func close() {
        onClose()
    }

    public func selectFile(id: String) {
        onSelectFile(id)
    }

    public func installProvider(id: String) {
        onInstallProvider(id)
    }

    public func toggleWorkflow(providerID: String) {
        onToggleWorkflow(providerID)
    }

    public func revealInFinder() {
        onRevealInFinder()
    }

    public func openMarkdownLink(_ url: URL) -> OpenURLAction.Result {
        onOpenMarkdownLink(url)
    }
}

@Observable
public final class SkillInstallSheetViewModel {
    public var data: SkillInstallSheetData
    public var selectedProviderID: String?

    private let onConfirm: (String) -> Void
    private let onCancel: () -> Void

    public init(
        data: SkillInstallSheetData,
        selectedProviderID: String? = nil,
        onConfirm: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.data = data
        self.selectedProviderID = selectedProviderID ?? data.providers.first?.id
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel()
    }

    public func confirmInstall() {
        guard let selectedProviderID else { return }
        onConfirm(selectedProviderID)
    }
}

@Observable
public final class DirectoryPickerSheetViewModel {
    public var data: DirectoryPickerSheetData
    public var selectedIDs: Set<Int>

    private let onConfirm: (Set<Int>) -> Void
    private let onCancel: () -> Void

    public init(
        data: DirectoryPickerSheetData,
        selectedIDs: Set<Int> = [],
        onConfirm: @escaping (Set<Int>) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.data = data
        self.selectedIDs = selectedIDs
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public func toggleSelection(_ id: Int) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    public func cancel() {
        onCancel()
    }

    public func confirm() {
        onConfirm(selectedIDs)
    }
}

@Observable
public final class MainSplitScaffoldViewModel {
    public init() {}
}

@Observable
public final class AgentDocCardViewViewModel {
    public let doc: AgentDocInfo
    public let searchText: String
    public var showingDeleteConfirmation: Bool

    public var title: String { doc.fileName }
    public var priorityIconName: String { doc.kind == .override ? "arrow.up.circle" : "doc.text" }
    public var priorityText: String {
        doc.kind == .override
            ? NSLocalizedString("agents.priority.override", value: "Higher priority (override)", comment: "Override priority hint")
            : NSLocalizedString("agents.priority.base", value: "Base priority", comment: "Base priority hint")
    }
    public var preview: String { doc.preview }

    public init(
        doc: AgentDocInfo,
        searchText: String,
        showingDeleteConfirmation: Bool = false
    ) {
        self.doc = doc
        self.searchText = searchText
        self.showingDeleteConfirmation = showingDeleteConfirmation
    }
}

@Observable
public final class McpServerCardViewViewModel {
    public var showingDeleteConfirmation: Bool

    public init(showingDeleteConfirmation: Bool = false) {
        self.showingDeleteConfirmation = showingDeleteConfirmation
    }
}

@Observable
public final class RuleCardViewViewModel {
    public let rule: RuleInfo
    public let searchText: String
    public var showingDeleteConfirmation: Bool

    public var title: String { rule.name }
    public var preview: String { rule.preview }
    public var relativePath: String { rule.relativePath }

    public init(
        rule: RuleInfo,
        searchText: String,
        showingDeleteConfirmation: Bool = false
    ) {
        self.rule = rule
        self.searchText = searchText
        self.showingDeleteConfirmation = showingDeleteConfirmation
    }
}

@Observable
public final class SkillCardViewViewModel {
    public var showingUninstallConfirmation: Bool

    public init(showingUninstallConfirmation: Bool = false) {
        self.showingUninstallConfirmation = showingUninstallConfirmation
    }
}

@Observable
public final class WorkflowCardViewViewModel {
    public var showingDeleteConfirmation: Bool

    public init(showingDeleteConfirmation: Bool = false) {
        self.showingDeleteConfirmation = showingDeleteConfirmation
    }
}

@Observable
public final class ProviderSkillCardViewViewModel {
    public init() {}
}

@Observable
public final class SkillVersionBadgeViewModel {
    public init() {}
}

@Observable
public final class SkillInstalledBadgeViewModel {
    public init() {}
}

@Observable
public final class SkillOrphanedBadgeViewModel {
    public init() {}
}

@Observable
public final class SkillRowViewViewModel {
    public var isExpanded: Bool

    public init(isExpanded: Bool = false) {
        self.isExpanded = isExpanded
    }
}

@Observable
public final class ProviderCardTemplateViewModel {
    public init() {}
}

@Observable
public final class ResourceCardScaffoldViewModel {
    public var isHovered: Bool

    public init(isHovered: Bool = false) {
        self.isHovered = isHovered
    }
}

@Observable
public final class ResourceCardMetaItemsViewViewModel {
    public init() {}
}

@Observable
public final class ResourceInstallStateViewViewModel {
    public init() {}
}

@Observable
public final class ResourceMcpCardViewViewModel {
    public init() {}
}

@Observable
public final class ResourceSkillCardViewViewModel {
    public init() {}
}

@Observable
public final class ResourceWorkflowCardViewViewModel {
    public init() {}
}

@Observable
public final class ResourceCenterCloseButtonViewModel {
    public init() {}
}

@Observable
public final class FloatingCloseButtonViewModel {
    public init() {}
}

@Observable
public final class HighlightedTextViewModel {
    public init() {}
}

@Observable
public final class ToastViewModel {
    public init() {}
}

@Observable
public final class SheetHeaderViewViewModel {
    public init() {}
}

@Observable
public final class SidebarColumnHeaderViewModel {
    public init() {}
}

@Observable
public final class SidebarColumnScaffoldViewModel {
    public init() {}
}

@Observable
public final class ThreeColumnScaffoldViewModel {
    public init() {}
}

@Observable
public final class SidebarProviderRowViewViewModel {
    public init() {}
}

@Observable
public final class SidebarSectionHeaderViewViewModel {
    public init() {}
}

@Observable
public final class SidebarToolRowViewViewModel {
    public init() {}
}
