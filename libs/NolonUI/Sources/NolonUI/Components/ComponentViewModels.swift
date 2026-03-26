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
public final class MainSplitScaffoldViewModel {
    public init() {}
}

@Observable
public final class AgentDocCardViewViewModel {
    public var showingDeleteConfirmation: Bool

    public init(showingDeleteConfirmation: Bool = false) {
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
    public var showingDeleteConfirmation: Bool

    public init(showingDeleteConfirmation: Bool = false) {
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
public final class ResourceCenterSidebarComponentViewModel {
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
public final class ProviderContentTabSidebarComponentViewModel {
    public init() {}
}

@Observable
public final class ProviderSidebarComponentViewModel {
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
