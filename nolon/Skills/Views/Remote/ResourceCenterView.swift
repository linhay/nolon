import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation
import OSLog

@MainActor
@Observable
final class ResourceCenterViewModel {
    private static let logger = Logger(subsystem: "nolon", category: "ResourceCenter")
    enum PostInstallRefreshKind: Hashable {
        case skill
        case workflow
        case mcp
    }

    var selectedRepository: RemoteRepository?
    var selectedTab: ResourceContentTabType? = .skills
    var searchText = ""
    var columnVisibility: NavigationSplitViewVisibility = .all
    var installedSlugs: Set<String> = []
    var installedSkills: [RemoteSkill] = []
    var installedWorkflowSlugs: Set<String> = []
    var installedMcpSlugs: Set<String> = []
    var importErrorMessage: String?
    var refreshTrigger: Int = 0
    private let statusService = InstalledResourceStatusService()
    @ObservationIgnored
    private var postInstallRefreshTasks: [PostInstallRefreshKind: Task<Void, Never>] = [:]

    init(selectedTab: ResourceContentTabType? = .skills) {
        self.selectedTab = selectedTab
    }

    deinit {
        postInstallRefreshTasks.values.forEach { $0.cancel() }
    }

    func effectiveTargetProvider(
        for repository: RemoteRepository?,
        fallback targetProvider: Provider?
    ) -> Provider? {
        guard repository?.templateType != .globalSkills else {
            return nil
        }
        return targetProvider
    }

    @MainActor
    func refreshInstalledResources(
        repository: SkillRepository,
        selectedRepository: RemoteRepository?,
        fallbackTargetProvider: Provider?,
        settings: ProviderSettings
    ) {
        let effectiveTargetProvider = effectiveTargetProvider(
            for: selectedRepository,
            fallback: fallbackTargetProvider
        )
        refreshInstalledSkills(repository: repository, targetProvider: effectiveTargetProvider, settings: settings)
        refreshInstalledWorkflows(targetProvider: effectiveTargetProvider)
        refreshInstalledMCPs(targetProvider: effectiveTargetProvider)
        refreshTrigger += 1
    }
    
    /// 刷新已安装技能列表
    /// - Parameters:
    ///   - repository: 全局技能仓库
    ///   - targetProvider: 目标 Provider（可选）
    ///   - settings: Provider 设置
    /// - 逻辑：
    ///   - 有 targetProvider → 检查该 Provider 中已安装的技能
    ///   - 无 targetProvider → 检查全局仓库
    @MainActor
    func refreshInstalledSkills(repository: SkillRepository, targetProvider: Provider?, settings: ProviderSettings) {
        do {
            let installedIDs = try statusService.installedSkillIDs(
                provider: targetProvider,
                repository: repository,
                settings: settings
            )
            installedSlugs = installedIDs
            installedSkills = try repository.listSkills()
                .filter { installedIDs.contains($0.id) }
                .map { skill in
                    RemoteSkill(
                        slug: skill.id,
                        displayName: skill.name,
                        summary: skill.description,
                        latestVersion: skill.version,
                        updatedAt: nil,
                        downloads: nil,
                        stars: nil,
                        localPath: skill.globalPath
                    )
                }
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
        } catch {
            Self.logger.error("Failed to scan provider: \(error.localizedDescription, privacy: .public)")
            installedSlugs = []
            installedSkills = []
        }
    }

    /// 刷新已安装 workflow 列表（仅针对目标 Provider）
    @MainActor
    func refreshInstalledWorkflows(targetProvider: Provider?) {
        installedWorkflowSlugs = statusService.installedWorkflowIDs(provider: targetProvider)
    }

    /// 刷新已安装 MCP 列表
    @MainActor
    func refreshInstalledMCPs(targetProvider: Provider?) {
        installedMcpSlugs = statusService.installedMcpIDs(provider: targetProvider)
    }

    @MainActor
    func schedulePostInstallRefresh(
        kind: PostInstallRefreshKind,
        repository: SkillRepository,
        selectedRepository: RemoteRepository?,
        fallbackTargetProvider: Provider?,
        settings: ProviderSettings
    ) {
        postInstallRefreshTasks[kind]?.cancel()
        postInstallRefreshTasks[kind] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(RemoteRefreshPolicy.installPropagationDelay))
            guard let self, !Task.isCancelled else { return }

            let effectiveTargetProvider = self.effectiveTargetProvider(
                for: selectedRepository,
                fallback: fallbackTargetProvider
            )

            switch kind {
            case .skill:
                self.refreshInstalledSkills(
                    repository: repository,
                    targetProvider: effectiveTargetProvider,
                    settings: settings
                )
            case .workflow:
                self.refreshInstalledWorkflows(targetProvider: effectiveTargetProvider)
            case .mcp:
                self.refreshInstalledMCPs(targetProvider: effectiveTargetProvider)
            }

            self.refreshTrigger += 1
            self.postInstallRefreshTasks[kind] = nil
        }
    }

    /// 根据搜索文本过滤技能
    func filterSkills(_ skills: [RemoteSkill]) -> [RemoteSkill] {
        if searchText.isEmpty {
            return skills
        }
        let searchLower = searchText.lowercased()
        return skills.filter { skill in
            skill.displayName.lowercased().contains(searchLower)
            || (skill.summary?.lowercased().contains(searchLower) ?? false)
        }
    }
}

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
        selectedTab: ResourceContentTabType? = .skills,
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
    
    var body: some View {
        let isClawdhub = viewModel.selectedRepository?.templateType == .clawdhub
        let effectiveTargetProvider = viewModel.effectiveTargetProvider(
            for: viewModel.selectedRepository,
            fallback: targetProvider
        )
        let layoutMode: UIThreeColumnScaffoldMode = isClawdhub ? .twoColumn : .threeColumn
        let selectedResourceTab: ResourceContentTabType? = isClawdhub ? .skills : viewModel.selectedTab
        UIThreeColumnScaffold(
            mode: layoutMode,
            columnVisibility: $viewModel.columnVisibility,
            sidebarWidth: .init(min: 200, ideal: 220, max: 240)
        ) {
            RemoteRepositorySidebarView(
                selectedRepository: $viewModel.selectedRepository,
                settings: settings,
                showsHeader: false,
                title: NSLocalizedString("resource.center.title", value: "Resource Center", comment: "Resource center title")
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
        .overlay(alignment: .top) {
            if let importErrorMessage = viewModel.importErrorMessage, !importErrorMessage.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DesignSystem.Colors.Status.warning)
                    Text(importErrorMessage)
                        .font(.callout)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        viewModel.importErrorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DesignSystem.Colors.Status.warning.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DesignSystem.Colors.Status.warning.opacity(0.28), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .overlay(alignment: .topTrailing) {
            if UITestSupport.isEnabled,
               onRegisterDeleteRequest != nil,
               onMakeDeleteRequestExecutor != nil {
                VStack(alignment: .trailing, spacing: 8) {
                    if let slug = UITestSupport.fixtureGlobalSkillSlug {
                        Button("Delete \(slug)") {
                            executeUITestGlobalSkillDelete(slug: slug)
                        }
                        .accessibilityIdentifier("uitest.delete-global-skill.\(slug)")
                    }

                    if let slug = UITestSupport.fixtureGlobalWorkflowSlug {
                        Button("Delete workflow \(slug)") {
                            executeUITestGlobalWorkflowDelete(slug: slug)
                        }
                        .accessibilityIdentifier("uitest.delete-global-workflow.\(slug)")
                    }

                    if let slug = UITestSupport.fixtureGlobalMCPSlug {
                        Button("Delete MCP \(slug)") {
                            executeUITestGlobalMCPDelete(slug: slug)
                        }
                        .accessibilityIdentifier("uitest.delete-global-mcp.\(slug)")
                    }

                    if let slug = UITestSupport.fixtureProviderSkillSlug,
                       let providerIndex = UITestSupport.initialSelectedProviderIndex {
                        Button("Delete provider skill \(slug)") {
                            executeUITestProviderSkillDelete(slug: slug, providerIndex: providerIndex)
                        }
                        .accessibilityIdentifier("uitest.delete-provider-skill.\(slug)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
        }
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
