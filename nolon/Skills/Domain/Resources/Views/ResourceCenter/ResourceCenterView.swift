import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI
import NolonUIFoundation

/// Main three-column split view for browsing resource catalogs
/// 与 MainSplitView 设计模式一致：
/// - 左1: RemoteRepositorySidebarView (仓库列表)
/// - 左2: ResourceCenterTabView (Tab 导航)
/// - 左3: ResourceCatalogGridView (网格视图)
struct ResourceCenterView: View, DebugPageLocatable {
    let settings: ProviderSettings
    let repository: SkillRepository
    let targetProvider: Provider?
    let onClose: () -> Void
    let onInstall: (RemoteSkill, Provider) -> Void
    let onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)?
    let onInstallMCP: ((RemoteMCP, Provider) -> Void)?
    let onRegisterDeleteRequest: ((String, RemoteContentType, Int?, Bool, String?) -> Int)?
    let onMakeDeleteRequestExecutor: ((Int) -> ResourceCatalogGridViewModel.DeleteRequestExecutor)?
    
    @State private var viewModel = ResourceCenterViewModel()
    private let draftService = RepositoryDraftService()
    
    init(
        settings: ProviderSettings,
        repository: SkillRepository,
        targetProvider: Provider? = nil,
        selectedTab: ResourceCenterTabID? = .skills,
        onClose: @escaping () -> Void = {},
        onInstall: @escaping (RemoteSkill, Provider) -> Void,
        onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)? = nil,
        onInstallMCP: ((RemoteMCP, Provider) -> Void)? = nil,
        onRegisterDeleteRequest: ((String, RemoteContentType, Int?, Bool, String?) -> Int)? = nil,
        onMakeDeleteRequestExecutor: ((Int) -> ResourceCatalogGridViewModel.DeleteRequestExecutor)? = nil
    ) {
        self.settings = settings
        self.repository = repository
        self.targetProvider = targetProvider
        self.onClose = onClose
        self.onInstall = onInstall
        self.onInstallWorkflow = onInstallWorkflow
        self.onInstallMCP = onInstallMCP
        self.onRegisterDeleteRequest = onRegisterDeleteRequest
        self.onMakeDeleteRequestExecutor = onMakeDeleteRequestExecutor
        self._viewModel = State(initialValue: ResourceCenterViewModel(selectedTab: selectedTab))
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        PageMarkerRouteResolver.resourceCenterItems(selectedTab: viewModel.selectedTab)
    }
    
    private func refreshData() {
        viewModel.refreshInstalledResources(
            repository: repository,
            selectedRepository: viewModel.selectedRepository,
            fallbackTargetProvider: targetProvider,
            settings: settings
        )
    }

    @MainActor
    private func handlePendingImportURLIfNeeded() {
        guard let pendingImportURL = settings.pendingImportURL else { return }
        let intent = draftService.parseImportIntent(from: pendingImportURL)

        switch intent.kind {
        case .clawhubSkill:
            guard let query = intent.slug, !query.isEmpty else {
                viewModel.importErrorMessage = NSLocalizedString(
                    "resource.import.invalid_clawhub",
                    value: "无法解析 Clawhub 技能链接，请检查后重试。",
                    comment: "Invalid clawhub import URL"
                )
                settings.pendingImportURL = nil
                return
            }
            if let clawdhubRepository = settings.remoteRepositories.first(where: { $0.templateType == .clawdhub }) {
                viewModel.selectedRepository = clawdhubRepository
            }
            viewModel.selectedTab = .skills
            viewModel.searchText = query
            viewModel.importErrorMessage = nil
            settings.pendingImportURL = nil
        case .gitRepository:
            // Keep existing Git import flow handled by sidebar/add-repository sheet.
            viewModel.importErrorMessage = nil
        case .unknown:
            viewModel.importErrorMessage = NSLocalizedString(
                "resource.import.unsupported",
                value: "无法识别导入链接。请使用 Clawhub 技能链接或 Git 仓库链接。",
                comment: "Unsupported import URL"
            )
            settings.pendingImportURL = nil
        }
    }

    private func applyUITestInitialStateIfNeeded() {
        guard UITestSupport.isEnabled else { return }

        if let template = UITestSupport.initialRepositoryTemplate {
            if let selectedRepository = settings.remoteRepositories.first(where: { $0.templateType == template }) {
                viewModel.selectedRepository = selectedRepository
            } else {
                switch template {
                case .globalSkills:
                    viewModel.selectedRepository = .globalSkills
                case .clawdhub:
                    viewModel.selectedRepository = .clawdhub
                case .localFolder, .git:
                    break
                }
            }
        }

        if let query = UITestSupport.initialSearchQuery {
            if let initialTab = UITestSupport.initialResourceTab {
                viewModel.selectedTab = initialTab
            } else {
                viewModel.selectedTab = .skills
            }
            viewModel.searchText = query
        }
    }

    private func executeUITestGlobalSkillDelete(slug: String) {
        executeUITestDelete(slug: slug, resourceType: .skill)
    }

    private func executeUITestGlobalWorkflowDelete(slug: String) {
        executeUITestDelete(slug: slug, resourceType: .workflow)
    }

    private func executeUITestGlobalMCPDelete(slug: String) {
        executeUITestDelete(slug: slug, resourceType: .mcp)
    }

    private func executeUITestProviderSkillDelete(slug: String, providerIndex: Int) {
        guard let onRegisterDeleteRequest, let onMakeDeleteRequestExecutor else { return }
        Task {
            let requestID = onRegisterDeleteRequest(
                slug,
                .skill,
                providerIndex,
                false,
                nil
            )
            let executeDeleteRequest = onMakeDeleteRequestExecutor(requestID)
            _ = await executeDeleteRequest()
            await MainActor.run {
                refreshData()
            }
        }
    }

    private func executeUITestDelete(slug: String, resourceType: RemoteContentType) {
        guard let onRegisterDeleteRequest, let onMakeDeleteRequestExecutor else { return }
        Task {
            let requestID = onRegisterDeleteRequest(
                slug,
                resourceType,
                nil,
                true,
                nil
            )
            let executeDeleteRequest = onMakeDeleteRequestExecutor(requestID)
            _ = await executeDeleteRequest()
            await MainActor.run {
                refreshData()
            }
        }
    }

    private var shouldShowUITestActions: Bool {
        UITestSupport.isEnabled
            && onRegisterDeleteRequest != nil
            && onMakeDeleteRequestExecutor != nil
    }

    private var uiTestActionItems: [ResourceCenterUITestActionData] {
        var items: [ResourceCenterUITestActionData] = []
        if let slug = UITestSupport.fixtureGlobalSkillSlug {
            items.append(
                .init(
                    id: "delete-global-skill-\(slug)",
                    kind: .deleteGlobalSkill,
                    slug: slug,
                    title: "Delete \(slug)",
                    accessibilityIdentifier: "uitest.delete-global-skill.\(slug)"
                )
            )
        }
        if let slug = UITestSupport.fixtureGlobalWorkflowSlug {
            items.append(
                .init(
                    id: "delete-global-workflow-\(slug)",
                    kind: .deleteGlobalWorkflow,
                    slug: slug,
                    title: "Delete workflow \(slug)",
                    accessibilityIdentifier: "uitest.delete-global-workflow.\(slug)"
                )
            )
        }
        if let slug = UITestSupport.fixtureGlobalMCPSlug {
            items.append(
                .init(
                    id: "delete-global-mcp-\(slug)",
                    kind: .deleteGlobalMCP,
                    slug: slug,
                    title: "Delete MCP \(slug)",
                    accessibilityIdentifier: "uitest.delete-global-mcp.\(slug)"
                )
            )
        }
        if let slug = UITestSupport.fixtureProviderSkillSlug,
           let providerIndex = UITestSupport.initialSelectedProviderIndex {
            items.append(
                .init(
                    id: "delete-provider-skill-\(slug)-\(providerIndex)",
                    kind: .deleteProviderSkill,
                    slug: slug,
                    providerIndex: providerIndex,
                    title: "Delete provider skill \(slug)",
                    accessibilityIdentifier: "uitest.delete-provider-skill.\(slug)"
                )
            )
        }
        return items
    }

    private func handleUITestActionTap(_ action: ResourceCenterUITestActionData) {
        switch action.kind {
        case .deleteGlobalSkill:
            executeUITestGlobalSkillDelete(slug: action.slug)
        case .deleteGlobalWorkflow:
            executeUITestGlobalWorkflowDelete(slug: action.slug)
        case .deleteGlobalMCP:
            executeUITestGlobalMCPDelete(slug: action.slug)
        case .deleteProviderSkill:
            guard let providerIndex = action.providerIndex else { return }
            executeUITestProviderSkillDelete(slug: action.slug, providerIndex: providerIndex)
        }
    }
    
    var body: some View {
        let isClawdhub = viewModel.selectedRepository?.templateType == .clawdhub
        let effectiveTargetProvider = viewModel.effectiveTargetProvider(
            for: viewModel.selectedRepository,
            fallback: targetProvider
        )
        let layoutMode: NolonUI.ThreeColumnScaffoldMode = isClawdhub ? .twoColumn : .threeColumn
        let selectedResourceTab: ResourceCenterTabID? = isClawdhub ? .skills : viewModel.selectedTab
        NolonUI.ThreeColumnScaffold(
            mode: layoutMode,
            columnVisibility: $viewModel.columnVisibility,
            sidebarWidth: .init(min: 200, ideal: 220, max: 240)
        ) {
            RemoteRepositorySidebarView(
                selectedRepository: $viewModel.selectedRepository,
                settings: settings,
                showsHeader: false
            )
        } content: {
            if isClawdhub {
                EmptyView()
            } else {
                ResourceCenterTabView(
                    repository: viewModel.selectedRepository,
                    selectedTab: $viewModel.selectedTab,
                    refreshTrigger: viewModel.refreshTrigger
                )
            }
        } detail: {
            ResourceCatalogGridView(
                repository: viewModel.selectedRepository,
                selectedTab: selectedResourceTab,
                searchText: $viewModel.searchText,
                installedSlugs: viewModel.installedSlugs,
                installedSkills: viewModel.installedSkills,
                installedWorkflowSlugs: viewModel.installedWorkflowSlugs,
                installedMcpSlugs: viewModel.installedMcpSlugs,
                providers: settings.providers,
                refreshTrigger: viewModel.refreshTrigger,
                targetProvider: effectiveTargetProvider,
                onInstall: { skill, provider in
                    onInstall(skill, provider)
                    viewModel.schedulePostInstallRefresh(
                        kind: .skill,
                        repository: repository,
                        selectedRepository: viewModel.selectedRepository,
                        fallbackTargetProvider: targetProvider,
                        settings: settings
                    )
                },
                onInstallWorkflow: { workflow, provider in
                    onInstallWorkflow?(workflow, provider)
                    viewModel.schedulePostInstallRefresh(
                        kind: .workflow,
                        repository: repository,
                        selectedRepository: viewModel.selectedRepository,
                        fallbackTargetProvider: targetProvider,
                        settings: settings
                    )
                },
                onInstallMCP: { mcp, provider in
                    onInstallMCP?(mcp, provider)
                    viewModel.schedulePostInstallRefresh(
                        kind: .mcp,
                        repository: repository,
                        selectedRepository: viewModel.selectedRepository,
                        fallbackTargetProvider: targetProvider,
                        settings: settings
                    )
                },
                onRegisterDeleteRequest: onRegisterDeleteRequest,
                onMakeDeleteRequestExecutor: onMakeDeleteRequestExecutor,
                onRefresh: {
                    refreshData()
                },
                onClose: onClose
            )
        }
        .debugPageLocator(debugPageMarkerItems)
        .resourceCenterOverlays(
            importErrorMessage: viewModel.importErrorMessage,
            onDismissImportError: {
                viewModel.importErrorMessage = nil
            },
            uiTestActions: shouldShowUITestActions ? uiTestActionItems : [],
            onTapUITestAction: handleUITestActionTap
        )
        .textSelection(.enabled)
        .onAppear {
            applyUITestInitialStateIfNeeded()
            refreshData()
            if viewModel.selectedRepository?.templateType == .clawdhub {
                viewModel.selectedTab = .skills
            }
        }
        .task(id: settings.pendingImportURL) {
            guard settings.pendingImportURL != nil else { return }
            handlePendingImportURLIfNeeded()
        }
        .onChange(of: viewModel.selectedRepository) { _, repository in
            if repository?.templateType == .clawdhub {
                viewModel.selectedTab = .skills
            } else {
                if viewModel.selectedTab == nil {
                    viewModel.selectedTab = .skills
                }
            }
            refreshData()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    #Preview {
        ResourceCenterView(
            settings: ProviderSettings(),
            repository: SkillRepository(),
            selectedTab: .skills,
            onInstall: { skill, provider in
                _ = skill
                _ = provider
            }
        )
        .frame(width: 900, height: 600)
    }
    
}
