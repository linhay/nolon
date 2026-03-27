import SwiftUI
import ProviderCatalog
import NolonResourceKit
import OSLog
import NolonUI
import NolonUIFoundation
#if os(macOS)
import AppKit
#endif

protocol RemoteCatalogQueryServing {
    func query(
        repository: RemoteRepository,
        kind: SkillsRepositoryFacade.RemoteCatalogKind,
        query: String?,
        limit: Int
    ) async throws -> RemoteCatalogQueryResult
}

extension RemoteCatalogQueryService: RemoteCatalogQueryServing {}

/// Detail 区域 - Grid 布局显示资源中心内容
struct ResourceCatalogGridView: View {
    @Environment(\.openWindow) private var openWindow
    private static let logger = Logger(subsystem: "com.nolon", category: "ResourceCatalogGrid")
    private static let installTimeoutNanoseconds: UInt64 = 45_000_000_000

    let repository: RemoteRepository?
    let selectedTab: ResourceCenterTabID?
    @Binding var searchText: String
    let installedSlugs: Set<String>
    let installedSkills: [RemoteSkill]
    let installedWorkflowSlugs: Set<String>
    let installedMcpSlugs: Set<String>
    let providers: [Provider]
    var refreshTrigger: Int
    let targetProvider: Provider?
    let onInstall: (RemoteSkill, Provider) -> Void
    let onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)?
    let onInstallMCP: ((RemoteMCP, Provider) -> Void)?
    let onRegisterDeleteRequest: ((String, RemoteContentType, Int?, Bool, String?) -> Int)?
    let onMakeDeleteRequestExecutor: ((Int) -> ResourceCatalogGridViewModel.DeleteRequestExecutor)?
    let onRefresh: (() -> Void)?
    let onClose: (() -> Void)?
    
    @State private var viewModel = ResourceCatalogGridViewModel()
    private var watchCenter = RemoteRepositoryWatchCenter.shared
    @State private var debouncedSearchText: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var retryTrigger: Int = 0
    @State private var showCopiedToast: Bool = false
    @State private var pendingSkillInstalls: Set<String> = []
    @State private var pendingWorkflowInstalls: Set<String> = []
    @State private var pendingMcpInstalls: Set<String> = []
    @State private var skillInstallErrors: [String: String] = [:]
    @State private var workflowInstallErrors: [String: String] = [:]
    @State private var mcpInstallErrors: [String: String] = [:]
    
    init(
        repository: RemoteRepository?,
        selectedTab: ResourceCenterTabID?,
        searchText: Binding<String>,
        installedSlugs: Set<String>,
        installedSkills: [RemoteSkill],
        installedWorkflowSlugs: Set<String>,
        installedMcpSlugs: Set<String>,
        providers: [Provider],
        refreshTrigger: Int,
        targetProvider: Provider?,
        onInstall: @escaping (RemoteSkill, Provider) -> Void,
        onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)? = nil,
        onInstallMCP: ((RemoteMCP, Provider) -> Void)? = nil,
        onRegisterDeleteRequest: ((String, RemoteContentType, Int?, Bool, String?) -> Int)? = nil,
        onMakeDeleteRequestExecutor: ((Int) -> ResourceCatalogGridViewModel.DeleteRequestExecutor)? = nil,
        onRefresh: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.repository = repository
        self.selectedTab = selectedTab
        self._searchText = searchText
        self._debouncedSearchText = State(initialValue: searchText.wrappedValue)
        self.installedSlugs = installedSlugs
        self.installedSkills = installedSkills
        self.installedWorkflowSlugs = installedWorkflowSlugs
        self.installedMcpSlugs = installedMcpSlugs
        self.providers = providers
        self.refreshTrigger = refreshTrigger
        self.targetProvider = targetProvider
        self.onInstall = onInstall
        self.onInstallWorkflow = onInstallWorkflow
        self.onInstallMCP = onInstallMCP
        self.onRegisterDeleteRequest = onRegisterDeleteRequest
        self.onMakeDeleteRequestExecutor = onMakeDeleteRequestExecutor
        self.onRefresh = onRefresh
        self.onClose = onClose
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]

    private var isClawdhub: Bool {
        repository?.templateType == .clawdhub
    }

    private var normalizedSearchQuery: String {
        Self.resolveSearchQuery(
            isClawdhub: isClawdhub,
            debouncedSearchText: debouncedSearchText,
            searchText: searchText
        )
    }

    static func resolveSearchQuery(
        isClawdhub: Bool,
        debouncedSearchText: String,
        searchText: String
    ) -> String {
        guard isClawdhub else { return "" }
        let debounced = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !debounced.isEmpty {
            return debounced
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        let trimmed = normalizedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return isClawdhub && !trimmed.isEmpty && viewModel.isLoading
    }

    private var repoSyncToken: Int {
        watchCenter.token(for: repository)
    }

    private var cacheBuster: String {
        "\(refreshTrigger)-\(repoSyncToken)-\(normalizedSearchQuery)-\(retryTrigger)"
    }

    private var loadTaskID: String {
        "\(repository?.id ?? "")-\(selectedTab?.rawValue ?? "")-\(cacheBuster)"
    }

    var body: some View {
        contentWithDetailSheets
            .textSelection(.enabled)
    }

    private var contentWithTask: some View {
        // 使用 .task(id:) 处理仓库切换，它会自动取消旧任务并启动新任务
        // 不需要 .onChange，避免重复触发导致请求被取消
        mainScaffoldContent
            .task(id: loadTaskID) {
                await loadContent()
            }
    }

    private var contentWithSearchDebounce: some View {
        contentWithTask
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    debouncedSearchText = newValue
                }
            }
    }

    private var contentWithPendingSync: some View {
        contentWithSearchDebounce
            .onChange(of: installedSlugs) { _, newValue in
                pendingSkillInstalls.subtract(newValue)
                for slug in newValue {
                    skillInstallErrors.removeValue(forKey: slug)
                }
            }
            .onChange(of: installedWorkflowSlugs) { _, newValue in
                pendingWorkflowInstalls.subtract(newValue)
                for slug in newValue {
                    workflowInstallErrors.removeValue(forKey: slug)
                }
            }
            .onChange(of: installedMcpSlugs) { _, newValue in
                pendingMcpInstalls.subtract(newValue)
                for slug in newValue {
                    mcpInstallErrors.removeValue(forKey: slug)
                }
            }
    }

    private var contentWithDetailSheets: some View {
        NolonUI.ResourceCatalogSheetsPresenter(
            selectedWorkflow: $viewModel.selectedWorkflowForDetail,
            selectedMCP: $viewModel.selectedMCPForDetail,
            deleteRequest: $viewModel.deleteRequest
        ) {
            contentWithPendingSync
        } workflowSheet: { workflow in
            NolonUI.RemoteResourceDetailSheetView(
                data: workflowDetailData(workflow),
                onInstall: { providerID in
                    guard let provider = providers.first(where: { $0.id == providerID }) else { return }
                    onInstallWorkflow?(workflow, provider)
                },
                onClose: {
                    viewModel.selectedWorkflowForDetail = nil
                }
            )
            .remoteDetailSheetFrame()
        } mcpSheet: { mcp in
            NolonUI.RemoteResourceDetailSheetView(
                data: mcpDetailData(mcp),
                onInstall: { providerID in
                    guard let provider = providers.first(where: { $0.id == providerID }) else { return }
                    onInstallMCP?(mcp, provider)
                },
                onClose: {
                    viewModel.selectedMCPForDetail = nil
                }
            )
            .remoteDetailSheetFrame()
        } deleteSheet: { request in
            let resourceSlug = request.resourceSlug
            let resourceType = request.resourceType
            NolonUI.ResourceDeleteTargetSheetView(
                data: .init(
                    resourceName: request.displayName,
                    resourceTypeName: localizedResourceTypeName(request.resourceType),
                    providers: providers.map { .init(id: $0.id, name: $0.name, iconName: $0.iconName) },
                    preferredProviderID: preferredDeleteProviderID
                ),
                onConfirm: { deleteAll, providerID in
                    let target: ResourceDeleteTarget
                    if deleteAll {
                        target = .allProvidersAndGlobalCache
                    } else {
                        guard let providerID else { return }
                        target = .provider(providerID)
                    }
                    Task {
                        await handleDeleteRequest(
                            resourceSlug: resourceSlug,
                            resourceType: resourceType,
                            target: target,
                            globalCachePathHint: request.localPath
                        )
                    }
                },
                onClose: {
                    viewModel.deleteRequest = nil
                }
            )
        }
            .onChange(of: viewModel.selectedSkillForDetail?.slug) { _, _ in
                guard let skill = viewModel.selectedSkillForDetail else { return }
                viewModel.selectedSkillForDetail = nil
                SkillDetailWindowCoordinator.shared.presentRemote(
                    skill: skill,
                    providers: providers,
                    targetProvider: targetProvider,
                    onInstall: { provider in
                        onInstall(skill, provider)
                    }
                )
                openWindow(id: SkillDetailWindowCoordinator.windowID)
            }
            .destructiveConfirmationDialog(
                data: directDeleteConfirmationDialogData,
                isPresented: isShowingDirectDeleteConfirmation,
                onConfirm: {
                    guard let request = viewModel.directDeleteConfirmationRequest else { return }
                    viewModel.directDeleteConfirmationRequest = nil
                    Task {
                        await handleDeleteRequest(
                            resourceSlug: request.resourceSlug,
                            resourceType: request.resourceType,
                            target: request.defaultTarget ?? .allProvidersAndGlobalCache,
                            globalCachePathHint: request.localPath
                        )
                    }
                },
                onCancel: {
                    viewModel.directDeleteConfirmationRequest = nil
                }
            )
            .messageAlert(
                title: NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"),
                message: deleteResultAlertMessageBinding
            )
            .onChange(of: viewModel.directDeleteConfirmationRequest) { _, request in
                guard UITestSupport.shouldAutoConfirmDelete,
                      let request,
                      let target = request.defaultTarget else { return }
                viewModel.directDeleteConfirmationRequest = nil
                Task {
                    await handleDeleteRequest(
                        resourceSlug: request.resourceSlug,
                        resourceType: request.resourceType,
                        target: target,
                        globalCachePathHint: request.localPath
                    )
                }
            }
    }

    private func loadContent() async {
        if let repository {
            watchCenter.ensureWatching(repository: repository)
        }
        await viewModel.loadContent(
            for: repository,
            tab: selectedTab,
            searchQuery: normalizedSearchQuery,
            cacheBuster: cacheBuster
        )
    }

    private var isShowingDirectDeleteConfirmation: Binding<Bool> {
        SwiftUI.Binding(
            get: { viewModel.directDeleteConfirmationRequest != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.directDeleteConfirmationRequest = nil
                }
            }
        )
    }

    private var directDeleteConfirmationDialogData: DestructiveConfirmationDialogData {
        DestructiveConfirmationDialogData(
            title: NSLocalizedString(
                "resource.delete.confirm.title",
                value: "Delete from all providers?",
                comment: "Delete all confirmation title"
            ),
            message: NSLocalizedString(
                "resource.delete.confirm.message",
                value: "This will remove the resource from all providers and delete global cache files.",
                comment: "Delete all confirmation message"
            ),
            confirmTitle: NSLocalizedString("action.delete", value: "Delete", comment: "Delete action")
        )
    }

    private var deleteResultAlertMessageBinding: Binding<String?> {
        Binding<String?>(
            get: {
                viewModel.isShowingDeleteResultAlert ? viewModel.deleteResultMessage : nil
            },
            set: { value in
                if value == nil {
                    viewModel.isShowingDeleteResultAlert = false
                }
            }
        )
    }

    @ViewBuilder
    private var contentBody: some View {
        let hasAnyContent = !(viewModel.skills.isEmpty && viewModel.workflows.isEmpty && viewModel.mcps.isEmpty)
        NolonUI.ResourceCatalogBodyStateContainerView(
            isLoading: viewModel.isLoading,
            hasAnyContent: hasAnyContent,
            errorMessage: viewModel.errorMessage,
            onCopyError: { message in
                copyErrorToClipboard(message)
            },
            onRetry: {
                retryTrigger += 1
            }
        ) {
            gridContent
        }
    }

    private func copyErrorToClipboard(_ message: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message, forType: .string)
        #endif
        showCopiedToast = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            showCopiedToast = false
        }
    }

    private var searchBar: some View {
        NolonUI.ResourceCatalogToolbarView(
            searchText: $searchText,
            isSearching: isSearching,
            onRefresh: onRefresh,
            onClose: onClose
        )
    }

    private var mainScaffoldContent: some View {
        NolonUI.ResourceCatalogMainScaffoldView(
            hasRepository: repository != nil,
            hasSelectedTab: selectedTab != nil,
        ) {
            VStack(spacing: 12) {
                searchBar
                contentBody
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        NolonUI.ResourceCatalogGridOverlayScaffold(showOverlay: showCopiedToast) {
            skillsGrid
        } overlay: {
            NolonUI.ToastView.copied()
        }
        .animation(.easeOut(duration: 0.2), value: showCopiedToast)
    }
    
    @ViewBuilder
    private var skillsGrid: some View {
        let shouldClientFilter = repository?.templateType != .clawdhub
        switch selectedTab {
        case .skills:
            let mergedSkills = mergeResourceCatalogSkills(
                catalogSkills: viewModel.skills,
                installedSkills: installedSkills,
                repositoryTemplateType: repository?.templateType
            )
            let filtered = filterResourceCatalogSkills(
                mergedSkills,
                searchText: shouldClientFilter ? searchText : normalizedSearchQuery
            )
            let buckets = ResourceInstallBuckets(
                items: filtered,
                isInstalled: { installedSlugs.contains($0.slug) },
                isInstalling: { pendingSkillInstalls.contains($0.slug) }
            )
            NolonUI.ResourceCatalogKindTabScaffold(
                kind: .skills,
                isEmpty: filtered.isEmpty,
                searchText: searchText,
                installedItems: buckets.installed,
                installingItems: buckets.installing,
                availableItems: buckets.available,
                columns: columns
            ) { skill in
                RemoteSkillCardView(
                    skill: skill,
                    isInstalled: true,
                    isInstalling: false,
                    installErrorMessage: nil,
                    targetProvider: targetProvider,
                    providers: providers,
                    onInstall: { provider in
                        onInstall(skill, provider)
                    },
                    onDeleteRequest: {
                        viewModel.requestDelete(
                            skill: skill,
                            repositoryTemplateType: repository?.templateType
                        )
                    },
                    isDeleting: viewModel.pendingSkillDeletes.contains(skill.slug),
                    onTap: {
                        viewModel.requestSkillDetail(skill)
                    }
                )
            } installingContent: { skill in
                RemoteSkillCardView(
                    skill: skill,
                    isInstalled: false,
                    isInstalling: true,
                    installErrorMessage: nil,
                    targetProvider: targetProvider,
                    providers: providers,
                    onInstall: { _ in },
                    onDeleteRequest: nil,
                    isDeleting: false,
                    onTap: {
                        viewModel.requestSkillDetail(skill)
                    }
                )
            } availableContent: { skill in
                RemoteSkillCardView(
                    skill: skill,
                    isInstalled: false,
                    isInstalling: false,
                    installErrorMessage: skillInstallErrors[skill.slug],
                    targetProvider: targetProvider,
                    providers: providers,
                    onInstall: { provider in
                        beginSkillInstall(skill, provider: provider)
                    },
                    onDeleteRequest: nil,
                    isDeleting: false,
                    onTap: {
                        viewModel.requestSkillDetail(skill)
                    }
                )
            } footerContent: {
                loadMoreRowIfNeeded
            }
            
        case .workflows:
            let filtered = shouldClientFilter ? viewModel.filteredWorkflows(searchText: searchText) : viewModel.workflows
            let buckets = ResourceInstallBuckets(
                items: filtered,
                isInstalled: { installedWorkflowSlugs.contains($0.slug) },
                isInstalling: { pendingWorkflowInstalls.contains($0.slug) }
            )
            NolonUI.ResourceCatalogKindTabScaffold(
                kind: .workflows,
                isEmpty: filtered.isEmpty,
                searchText: searchText,
                installedItems: buckets.installed,
                installingItems: buckets.installing,
                availableItems: buckets.available,
                columns: columns
            ) { workflow in
                RemoteWorkflowCardView(
                    workflow: workflow,
                    isInstalled: true,
                    isInstalling: false,
                    installErrorMessage: nil,
                    isSelected: viewModel.selectedWorkflowForDetail?.slug == workflow.slug,
                    targetProvider: targetProvider,
                    providers: providers,
                    onInstall: { provider in
                        onInstallWorkflow?(workflow, provider)
                    },
                    onDeleteRequest: {
                        viewModel.requestDelete(
                            workflow: workflow,
                            repositoryTemplateType: repository?.templateType
                        )
                    },
                    isDeleting: viewModel.pendingWorkflowDeletes.contains(workflow.slug),
                    onTap: {
                        viewModel.selectedWorkflowForDetail = workflow
                    }
                )
            } installingContent: { workflow in
                RemoteWorkflowCardView(
                    workflow: workflow,
                    isInstalled: false,
                    isInstalling: true,
                    installErrorMessage: nil,
                    isSelected: viewModel.selectedWorkflowForDetail?.slug == workflow.slug,
                    targetProvider: targetProvider,
                    providers: providers,
                    onInstall: { _ in },
                    onDeleteRequest: nil,
                    isDeleting: false,
                    onTap: {
                        viewModel.selectedWorkflowForDetail = workflow
                    }
                )
            } availableContent: { workflow in
                RemoteWorkflowCardView(
                    workflow: workflow,
                    isInstalled: false,
                    isInstalling: false,
                    installErrorMessage: workflowInstallErrors[workflow.slug],
                    isSelected: viewModel.selectedWorkflowForDetail?.slug == workflow.slug,
                    targetProvider: targetProvider,
                    providers: providers,
                    onInstall: { provider in
                        beginWorkflowInstall(workflow, provider: provider)
                    },
                    onDeleteRequest: nil,
                    isDeleting: false,
                    onTap: {
                        viewModel.selectedWorkflowForDetail = workflow
                    }
                )
            } footerContent: {
                loadMoreRowIfNeeded
            }
            
        case .mcps:
            let filtered = shouldClientFilter ? viewModel.filteredMCPs(searchText: searchText) : viewModel.mcps
            let buckets = ResourceInstallBuckets(
                items: filtered,
                isInstalled: { installedMcpSlugs.contains($0.slug) },
                isInstalling: { pendingMcpInstalls.contains($0.slug) }
            )
            NolonUI.ResourceCatalogKindTabScaffold(
                kind: .mcps,
                isEmpty: filtered.isEmpty,
                searchText: searchText,
                installedItems: buckets.installed,
                installingItems: buckets.installing,
                availableItems: buckets.available,
                columns: columns
            ) { mcp in
                RemoteMCPCardView(
                    mcp: mcp,
                    isInstalled: true,
                    isInstalling: false,
                    installErrorMessage: nil,
                    isSelected: viewModel.selectedMCPForDetail?.slug == mcp.slug,
                    targetProvider: targetProvider,
                    providers: providers,
                    onInstall: { provider in
                        onInstallMCP?(mcp, provider)
                    },
                    onDeleteRequest: {
                        viewModel.requestDelete(
                            mcp: mcp,
                            repositoryTemplateType: repository?.templateType
                        )
                    },
                    isDeleting: viewModel.pendingMcpDeletes.contains(mcp.slug),
                    onTap: {
                        viewModel.selectedMCPForDetail = mcp
                    }
                )
            } installingContent: { mcp in
                RemoteMCPCardView(
                    mcp: mcp,
                    isInstalled: false,
                    isInstalling: true,
                    installErrorMessage: nil,
                    isSelected: viewModel.selectedMCPForDetail?.slug == mcp.slug,
                    targetProvider: targetProvider,
                    providers: providers,
                    onInstall: { _ in },
                    onDeleteRequest: nil,
                    isDeleting: false,
                    onTap: {
                        viewModel.selectedMCPForDetail = mcp
                    }
                )
            } availableContent: { mcp in
                RemoteMCPCardView(
                    mcp: mcp,
                    isInstalled: false,
                    isInstalling: false,
                    installErrorMessage: mcpInstallErrors[mcp.slug],
                    isSelected: viewModel.selectedMCPForDetail?.slug == mcp.slug,
                    targetProvider: targetProvider,
                    providers: providers,
                    onInstall: { provider in
                        beginMCPInstall(mcp, provider: provider)
                    },
                    onDeleteRequest: nil,
                    isDeleting: false,
                    onTap: {
                        viewModel.selectedMCPForDetail = mcp
                    }
                )
            } footerContent: {
                loadMoreRowIfNeeded
            }
            
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var loadMoreRowIfNeeded: some View {
        NolonUI.ResourceCatalogLoadMoreStateView(
            isEnabled: repository?.templateType == .clawdhub,
            loadMoreErrorMessage: viewModel.loadMoreErrorMessage,
            canLoadMore: viewModel.canLoadMore,
            isLoadingMore: viewModel.isLoadingMore,
            isLoading: viewModel.isLoading,
            hasAnyContent: !(viewModel.skills.isEmpty && viewModel.workflows.isEmpty && viewModel.mcps.isEmpty),
            onLoadMore: {
                triggerLoadMore()
            }
        )
    }

    private func triggerLoadMore() {
        Task {
            await viewModel.loadMore(
                repository: repository,
                tab: selectedTab,
                searchQuery: normalizedSearchQuery
            )
        }
    }

    private var preferredDeleteProviderID: String? {
        targetProvider?.id ?? providers.first?.id
    }

    private func localizedResourceTypeName(_ resourceType: RemoteContentType) -> String {
        switch resourceType {
        case .skill:
            return NSLocalizedString("tab.skills", comment: "Skills")
        case .workflow:
            return NSLocalizedString("tab.workflows", comment: "Workflows")
        case .mcp:
            return NSLocalizedString("tab.mcps", comment: "MCPs")
        }
    }

    private func workflowDetailData(_ workflow: RemoteWorkflow) -> RemoteResourceDetailData {
        var sections: [RemoteResourceDetailData.Section] = []

        if let description = RemoteResourceDetailBuilders.descriptionSection(summary: workflow.summary) {
            sections.append(description)
        }

        if let changelog = RemoteResourceDetailBuilders.changelogSection(changelog: workflow.latestVersion?.changelog) {
            sections.append(changelog)
        }

        var stats: [RemoteResourceDetailData.StatItem] = []
        if let values = workflow.stats {
            stats.append(contentsOf: RemoteResourceDetailBuilders.commonStats(stars: values.stars, downloads: values.downloads))
            if let usages = values.usages {
                stats.append(RemoteResourceDetailBuilders.usagesStat(usages))
            }
        }

        return .init(
            title: workflow.displayName,
            subtitle: workflowVersionSubtitle(workflow),
            stats: stats,
            sections: sections,
            providers: providers.map { .init(id: $0.id, name: $0.name, iconName: $0.iconName) },
            preferredProviderID: targetProvider?.id
        )
    }

    private func mcpDetailData(_ mcp: RemoteMCP) -> RemoteResourceDetailData {
        var sections: [RemoteResourceDetailData.Section] = []

        if let description = RemoteResourceDetailBuilders.descriptionSection(summary: mcp.summary) {
            sections.append(description)
        }

        if let config = mcp.configuration {
            if let command = config.command, !command.isEmpty {
                sections.append(.codeBlock(id: "command", title: "Command", content: command))
            }
            if let args = config.args, !args.isEmpty {
                sections.append(.list(id: "args", title: "Arguments", items: args, monospaced: true))
            }
            if let env = config.env, !env.isEmpty {
                let envItems = env.keys.sorted().compactMap { key -> String? in
                    guard let value = env[key] else { return nil }
                    return "\(key)=\(value)"
                }
                sections.append(.kvList(id: "env", title: "Environment Variables", items: envItems, monospaced: true))
            }
        }

        if let changelog = RemoteResourceDetailBuilders.changelogSection(changelog: mcp.latestVersion?.changelog) {
            sections.append(changelog)
        }

        var stats: [RemoteResourceDetailData.StatItem] = []
        if let values = mcp.stats {
            stats.append(contentsOf: RemoteResourceDetailBuilders.commonStats(stars: values.stars, downloads: values.downloads))
            if let installs = values.installs {
                stats.append(RemoteResourceDetailBuilders.installsStat(installs))
            }
        }

        return .init(
            title: mcp.displayName,
            subtitle: mcpVersionSubtitle(mcp),
            stats: stats,
            sections: sections,
            providers: providers.map { .init(id: $0.id, name: $0.name, iconName: $0.iconName) },
            preferredProviderID: targetProvider?.id
        )
    }

    private func workflowVersionSubtitle(_ workflow: RemoteWorkflow) -> String? {
        guard let version = workflow.latestVersion else { return nil }
        return RemoteResourceDetailBuilders.versionSubtitle(version: version.version, createdAt: version.createdAt)
    }

    private func mcpVersionSubtitle(_ mcp: RemoteMCP) -> String? {
        guard let version = mcp.latestVersion else { return nil }
        return RemoteResourceDetailBuilders.versionSubtitle(version: version.version, createdAt: version.createdAt)
    }

    private func beginSkillInstall(_ skill: RemoteSkill, provider: Provider) {
        Self.logger.info(
            "UI install click(skill). slug=\(skill.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
        )
        skillInstallErrors.removeValue(forKey: skill.slug)
        pendingSkillInstalls.insert(skill.slug)
        onInstall(skill, provider)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.installTimeoutNanoseconds)
            guard pendingSkillInstalls.contains(skill.slug) else { return }
            pendingSkillInstalls.remove(skill.slug)
            if !installedSlugs.contains(skill.slug) {
                Self.logger.error(
                    "UI install timeout(skill). slug=\(skill.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
                )
                skillInstallErrors[skill.slug] = NSLocalizedString(
                    "remote.install.failed.hint",
                    value: "Install timed out. Click Retry.",
                    comment: "Remote install failed hint"
                )
            }
        }
    }

    private func beginWorkflowInstall(_ workflow: RemoteWorkflow, provider: Provider) {
        Self.logger.info(
            "UI install click(workflow). slug=\(workflow.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
        )
        workflowInstallErrors.removeValue(forKey: workflow.slug)
        pendingWorkflowInstalls.insert(workflow.slug)
        onInstallWorkflow?(workflow, provider)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.installTimeoutNanoseconds)
            guard pendingWorkflowInstalls.contains(workflow.slug) else { return }
            pendingWorkflowInstalls.remove(workflow.slug)
            if !installedWorkflowSlugs.contains(workflow.slug) {
                Self.logger.error(
                    "UI install timeout(workflow). slug=\(workflow.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
                )
                workflowInstallErrors[workflow.slug] = NSLocalizedString(
                    "remote.install.failed.hint",
                    value: "Install timed out. Click Retry.",
                    comment: "Remote install failed hint"
                )
            }
        }
    }

    private func beginMCPInstall(_ mcp: RemoteMCP, provider: Provider) {
        Self.logger.info(
            "UI install click(mcp). slug=\(mcp.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
        )
        mcpInstallErrors.removeValue(forKey: mcp.slug)
        pendingMcpInstalls.insert(mcp.slug)
        onInstallMCP?(mcp, provider)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.installTimeoutNanoseconds)
            guard pendingMcpInstalls.contains(mcp.slug) else { return }
            pendingMcpInstalls.remove(mcp.slug)
            if !installedMcpSlugs.contains(mcp.slug) {
                Self.logger.error(
                    "UI install timeout(mcp). slug=\(mcp.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
                )
                mcpInstallErrors[mcp.slug] = NSLocalizedString(
                    "remote.install.failed.hint",
                    value: "Install timed out. Click Retry.",
                    comment: "Remote install failed hint"
                )
            }
        }
    }

    @MainActor
    private func handleDeleteRequest(
        resourceSlug: String,
        resourceType: RemoteContentType,
        target: ResourceDeleteTarget,
        globalCachePathHint: String? = nil
    ) async {
        await viewModel.executeDelete(
            resourceSlug: resourceSlug,
            resourceType: resourceType,
            target: target,
            globalCachePathHint: globalCachePathHint,
            providers: providers,
            onRegisterDeleteRequest: onRegisterDeleteRequest,
            onMakeDeleteRequestExecutor: onMakeDeleteRequestExecutor,
            onRefresh: onRefresh
        )
    }
}

func mergeResourceCatalogSkills(
    catalogSkills: [RemoteSkill],
    installedSkills: [RemoteSkill],
    repositoryTemplateType: RepositoryTemplate?
) -> [RemoteSkill] {
    guard repositoryTemplateType == .clawdhub else {
        return catalogSkills
    }
    let catalogSlugs = Set(catalogSkills.map(\.slug))
    let installedOnly = installedSkills.filter { !catalogSlugs.contains($0.slug) }
    return catalogSkills + installedOnly
}

func filterResourceCatalogSkills(
    _ skills: [RemoteSkill],
    searchText: String
) -> [RemoteSkill] {
    let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else { return skills }
    return skills.filter { skill in
        skill.displayName.localizedStandardContains(trimmedQuery)
        || (skill.summary?.localizedStandardContains(trimmedQuery) ?? false)
    }
}
