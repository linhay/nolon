import SwiftUI
import ProviderCatalog
import Observation
#if os(macOS)
import AppKit
#endif

/// Remote Skills Grid ViewModel
@MainActor
@Observable
final class RemoteSkillsGridViewModel {
    var skills: [RemoteSkill] = []
    var workflows: [RemoteWorkflow] = []
    var mcps: [RemoteMCP] = []
    var isLoading = false
    var errorMessage: String?
    var canLoadMore = false
    var isLoadingMore = false
    var selectedSkillForDetail: RemoteSkill?
    var selectedWorkflowForDetail: RemoteWorkflow?
    var selectedMCPForDetail: RemoteMCP?

    private struct CacheKey: Hashable {
        let repositoryID: String
        let tab: RemoteContentTabType
        let query: String
    }

    private struct CacheEntry {
        var skills: [RemoteSkill] = []
        var workflows: [RemoteWorkflow] = []
        var mcps: [RemoteMCP] = []
        var errorMessage: String?
        var cacheBuster: String
        var limit: Int
        var canLoadMore: Bool
    }

    private var cache: [CacheKey: CacheEntry] = [:]
    private var currentLoadID: UUID?
    private let pageSize: Int = 20
    private let maxLimit: Int = 200

    private func mapKind(_ tab: RemoteContentTabType) -> SkillsRepositoryFacade.RemoteCatalogKind {
        switch tab {
        case .skills:
            return .skill
        case .workflows:
            return .workflow
        case .mcps:
            return .mcp
        }
    }

    private func mapSkill(_ item: SkillsRepositoryFacade.RemoteCatalogItem) -> RemoteSkill {
        RemoteSkill(
            slug: item.slug,
            displayName: item.displayName,
            summary: item.summary,
            latestVersion: item.latestVersion,
            updatedAt: item.updatedAt,
            downloads: item.downloads,
            stars: item.stars
        )
    }

    private func mapWorkflow(_ item: SkillsRepositoryFacade.RemoteCatalogItem) -> RemoteWorkflow {
        RemoteWorkflow(
            slug: item.slug,
            displayName: item.displayName,
            summary: item.summary,
            latestVersion: item.latestVersion,
            updatedAt: item.updatedAt,
            downloads: item.downloads,
            stars: item.stars
        )
    }

    private func mapMCP(_ item: SkillsRepositoryFacade.RemoteCatalogItem) -> RemoteMCP {
        RemoteMCP(
            slug: item.slug,
            displayName: item.displayName,
            summary: item.summary,
            latestVersion: item.latestVersion,
            updatedAt: item.updatedAt,
            downloads: item.downloads,
            stars: item.stars,
            installs: item.installs
        )
    }
    
    // 过滤逻辑现在在这里
    func filteredSkills(searchText: String) -> [RemoteSkill] {
        if searchText.isEmpty {
            return skills
        }
        let searchLower = searchText.lowercased()
        return skills.filter { skill in
            skill.displayName.lowercased().contains(searchLower)
            || (skill.summary?.lowercased().contains(searchLower) ?? false)
        }
    }
    
    func filteredWorkflows(searchText: String) -> [RemoteWorkflow] {
        if searchText.isEmpty {
            return workflows
        }
        let searchLower = searchText.lowercased()
        return workflows.filter { workflow in
            workflow.displayName.lowercased().contains(searchLower)
            || (workflow.summary?.lowercased().contains(searchLower) ?? false)
        }
    }
    
    func filteredMCPs(searchText: String) -> [RemoteMCP] {
        if searchText.isEmpty {
            return mcps
        }
        let searchLower = searchText.lowercased()
        return mcps.filter { mcp in
            mcp.displayName.lowercased().contains(searchLower)
            || (mcp.summary?.lowercased().contains(searchLower) ?? false)
        }
    }
    
    func loadContent(for repository: RemoteRepository?, tab: RemoteContentTabType?, searchQuery: String, cacheBuster: String) async {
        guard let repository = repository, let tab = tab else {
            skills = []
            workflows = []
            mcps = []
            errorMessage = nil
            isLoading = false
            currentLoadID = nil
            canLoadMore = false
            return
        }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuery = !trimmedQuery.isEmpty
        let cacheKey = CacheKey(repositoryID: repository.id, tab: tab, query: trimmedQuery)
        let loadID = UUID()
        currentLoadID = loadID

        if let cached = cache[cacheKey] {
            applyCached(cached, for: tab)
            // cacheBuster 相同 → 直接使用缓存，不再重复加载
            if cached.cacheBuster == cacheBuster {
                return
            }
        } else {
            clearAllContent()
        }

        // 切换仓库/Tab 或手动刷新时：清空旧错误，避免展示上一个仓库的错误
        errorMessage = nil
        isLoading = true
        isLoadingMore = false

        defer {
            // 仅当本次任务仍然是最新请求时才落地 isLoading，避免竞态覆盖
            if currentLoadID == loadID {
                isLoading = false
            }
        }
        
        do {
            let cachedLimit = cache[cacheKey]?.limit ?? pageSize
            switch repository.templateType {
            case .clawdhub:
                let kind = mapKind(tab)
                let listResult = try await SkillsRepositoryFacade.listRemoteResources(
                    kind: kind,
                    query: hasQuery ? trimmedQuery : nil,
                    limit: cachedLimit,
                    baseURL: repository.baseURL
                )
                switch tab {
                case .skills:
                    let result = listResult.items.map(mapSkill)
                    guard currentLoadID == loadID else { return }
                    skills = result
                    let canLoad = result.count >= cachedLimit && cachedLimit < maxLimit
                    canLoadMore = canLoad
                    cache[cacheKey] = CacheEntry(skills: result, workflows: [], mcps: [], errorMessage: nil, cacheBuster: cacheBuster, limit: cachedLimit, canLoadMore: canLoad)
                case .workflows:
                    let result = listResult.items.map(mapWorkflow)
                    guard currentLoadID == loadID else { return }
                    workflows = result
                    let canLoad = result.count >= cachedLimit && cachedLimit < maxLimit
                    canLoadMore = canLoad
                    cache[cacheKey] = CacheEntry(skills: [], workflows: result, mcps: [], errorMessage: nil, cacheBuster: cacheBuster, limit: cachedLimit, canLoadMore: canLoad)
                case .mcps:
                    let result = listResult.items.map(mapMCP)
                    guard currentLoadID == loadID else { return }
                    mcps = result
                    let canLoad = result.count >= cachedLimit && cachedLimit < maxLimit
                    canLoadMore = canLoad
                    cache[cacheKey] = CacheEntry(skills: [], workflows: [], mcps: result, errorMessage: nil, cacheBuster: cacheBuster, limit: cachedLimit, canLoadMore: canLoad)
                }
                
            case .globalSkills:
                // Use GlobalCacheRepository for global cache
                let cacheRepo = GlobalCacheRepository()
                
                switch tab {
                case .skills:
                    let result = try await cacheRepo.fetchSkills(query: nil, limit: 100)
                    guard currentLoadID == loadID else { return }
                    skills = result
                    canLoadMore = false
                    cache[cacheKey] = CacheEntry(skills: result, workflows: [], mcps: [], errorMessage: nil, cacheBuster: cacheBuster, limit: 100, canLoadMore: false)
                case .workflows:
                    let result = try await cacheRepo.fetchWorkflows(query: nil, limit: 100)
                    guard currentLoadID == loadID else { return }
                    workflows = result
                    canLoadMore = false
                    cache[cacheKey] = CacheEntry(skills: [], workflows: result, mcps: [], errorMessage: nil, cacheBuster: cacheBuster, limit: 100, canLoadMore: false)
                case .mcps:
                    let result = try await cacheRepo.fetchMCPs(query: nil, limit: 100)
                    guard currentLoadID == loadID else { return }
                    mcps = result
                    canLoadMore = false
                    cache[cacheKey] = CacheEntry(skills: [], workflows: [], mcps: result, errorMessage: nil, cacheBuster: cacheBuster, limit: 100, canLoadMore: false)
                }
                
            case .localFolder, .git:
                let paths = repository.effectiveSkillsPaths
                guard !paths.isEmpty else {
                    throw RepositoryError.invalidConfiguration
                }
                
                if repository.templateType == .git {
                    let gitRepo = try GitRepository(repository: repository)
                    
                    switch tab {
                    case .skills:
                        let result = try await gitRepo.fetchSkills(query: nil, limit: 100)
                        guard currentLoadID == loadID else { return }
                        skills = result
                        canLoadMore = false
                        cache[cacheKey] = CacheEntry(skills: result, workflows: [], mcps: [], errorMessage: nil, cacheBuster: cacheBuster, limit: 100, canLoadMore: false)
                    case .workflows:
                        let result = try await gitRepo.fetchWorkflows(query: nil, limit: 100)
                        guard currentLoadID == loadID else { return }
                        workflows = result
                        canLoadMore = false
                        cache[cacheKey] = CacheEntry(skills: [], workflows: result, mcps: [], errorMessage: nil, cacheBuster: cacheBuster, limit: 100, canLoadMore: false)
                    case .mcps:
                        let result = try await gitRepo.fetchMCPs(query: nil, limit: 100)
                        guard currentLoadID == loadID else { return }
                        mcps = result
                        canLoadMore = false
                        cache[cacheKey] = CacheEntry(skills: [], workflows: [], mcps: result, errorMessage: nil, cacheBuster: cacheBuster, limit: 100, canLoadMore: false)
                    }
                } else {
                    // Local folder repository
                    let localRepo = LocalFolderRepository(
                        id: repository.id,
                        name: repository.name,
                        basePaths: paths
                    )
                    
                    switch tab {
                    case .skills:
                        let result = try await localRepo.fetchSkills(query: nil, limit: 100)
                        guard currentLoadID == loadID else { return }
                        skills = result
                        canLoadMore = false
                        cache[cacheKey] = CacheEntry(skills: result, workflows: [], mcps: [], errorMessage: nil, cacheBuster: cacheBuster, limit: 100, canLoadMore: false)
                    case .workflows:
                        let result = try await localRepo.fetchWorkflows(query: nil, limit: 100)
                        guard currentLoadID == loadID else { return }
                        workflows = result
                        canLoadMore = false
                        cache[cacheKey] = CacheEntry(skills: [], workflows: result, mcps: [], errorMessage: nil, cacheBuster: cacheBuster, limit: 100, canLoadMore: false)
                    case .mcps:
                        let result = try await localRepo.fetchMCPs(query: nil, limit: 100)
                        guard currentLoadID == loadID else { return }
                        mcps = result
                        canLoadMore = false
                        cache[cacheKey] = CacheEntry(skills: [], workflows: [], mcps: result, errorMessage: nil, cacheBuster: cacheBuster, limit: 100, canLoadMore: false)
                    }
                }
            }
        } catch is CancellationError {
            // 任务被取消（如用户快速切换仓库），静默忽略，不显示错误
            return
        } catch let error as URLError where error.code == .cancelled {
            // 网络请求被取消，静默忽略，不显示错误
            return
        } catch {
            guard currentLoadID == loadID else { return }
            clearAllContent()
            errorMessage = error.localizedDescription
            canLoadMore = false
            cache[cacheKey] = CacheEntry(skills: [], workflows: [], mcps: [], errorMessage: error.localizedDescription, cacheBuster: cacheBuster, limit: pageSize, canLoadMore: false)
        }
    }

    func loadMore(repository: RemoteRepository?, tab: RemoteContentTabType?, searchQuery: String) async {
        guard let repository = repository, let tab = tab else { return }
        guard repository.templateType == .clawdhub else { return }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = CacheKey(repositoryID: repository.id, tab: tab, query: trimmedQuery)
        let currentLimit = cache[cacheKey]?.limit ?? pageSize
        let nextLimit = min(maxLimit, currentLimit + pageSize)
        guard nextLimit > currentLimit else { return }

        let loadID = UUID()
        currentLoadID = loadID
        isLoadingMore = true

        defer {
            if currentLoadID == loadID {
                isLoadingMore = false
            }
        }

        do {
            let kind = mapKind(tab)
            let listResult = try await SkillsRepositoryFacade.listRemoteResources(
                kind: kind,
                query: trimmedQuery.isEmpty ? nil : trimmedQuery,
                limit: nextLimit,
                baseURL: repository.baseURL
            )
            switch tab {
            case .skills:
                let result = listResult.items.map(mapSkill)
                guard currentLoadID == loadID else { return }
                skills = result
                let canLoad = result.count >= nextLimit && nextLimit < maxLimit
                canLoadMore = canLoad
                cache[cacheKey] = CacheEntry(skills: result, workflows: [], mcps: [], errorMessage: nil, cacheBuster: cache[cacheKey]?.cacheBuster ?? "", limit: nextLimit, canLoadMore: canLoad)
            case .workflows:
                let result = listResult.items.map(mapWorkflow)
                guard currentLoadID == loadID else { return }
                workflows = result
                let canLoad = result.count >= nextLimit && nextLimit < maxLimit
                canLoadMore = canLoad
                cache[cacheKey] = CacheEntry(skills: [], workflows: result, mcps: [], errorMessage: nil, cacheBuster: cache[cacheKey]?.cacheBuster ?? "", limit: nextLimit, canLoadMore: canLoad)
            case .mcps:
                let result = listResult.items.map(mapMCP)
                guard currentLoadID == loadID else { return }
                mcps = result
                let canLoad = result.count >= nextLimit && nextLimit < maxLimit
                canLoadMore = canLoad
                cache[cacheKey] = CacheEntry(skills: [], workflows: [], mcps: result, errorMessage: nil, cacheBuster: cache[cacheKey]?.cacheBuster ?? "", limit: nextLimit, canLoadMore: canLoad)
            }
        } catch {
            guard currentLoadID == loadID else { return }
            errorMessage = error.localizedDescription
            canLoadMore = false
            cache[cacheKey] = CacheEntry(skills: skills, workflows: workflows, mcps: mcps, errorMessage: error.localizedDescription, cacheBuster: cache[cacheKey]?.cacheBuster ?? "", limit: currentLimit, canLoadMore: false)
        }
    }

    private func applyCached(_ cached: CacheEntry, for tab: RemoteContentTabType) {
        switch tab {
        case .skills:
            skills = cached.skills
            workflows = []
            mcps = []
        case .workflows:
            skills = []
            workflows = cached.workflows
            mcps = []
        case .mcps:
            skills = []
            workflows = []
            mcps = cached.mcps
        }

        errorMessage = cached.errorMessage
        isLoading = false
        canLoadMore = cached.canLoadMore
    }

    private func clearAllContent() {
        skills = []
        workflows = []
        mcps = []
        canLoadMore = false
    }
}

/// Detail 区域 - Grid 布局显示远程技能
struct RemoteSkillsGridView: View {
    let repository: RemoteRepository?
    let selectedTab: RemoteContentTabType?
    @Binding var searchText: String
    let installedSlugs: Set<String>
    let installedWorkflowSlugs: Set<String>
    let installedMcpSlugs: Set<String>
    let providers: [Provider]
    var refreshTrigger: Int
    let targetProvider: Provider?
    let onInstall: (RemoteSkill, Provider) -> Void
    let onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)?
    let onInstallMCP: ((RemoteMCP, Provider) -> Void)?
    
    @State private var viewModel = RemoteSkillsGridViewModel()
    @ObservedObject private var watchCenter = RemoteRepositoryWatchCenter.shared
    @State private var debouncedSearchText: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var retryTrigger: Int = 0
    @State private var showCopiedToast: Bool = false
    
    init(
        repository: RemoteRepository?,
        selectedTab: RemoteContentTabType?,
        searchText: Binding<String>,
        installedSlugs: Set<String>,
        installedWorkflowSlugs: Set<String>,
        installedMcpSlugs: Set<String>,
        providers: [Provider],
        refreshTrigger: Int,
        targetProvider: Provider?,
        onInstall: @escaping (RemoteSkill, Provider) -> Void,
        onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)? = nil,
        onInstallMCP: ((RemoteMCP, Provider) -> Void)? = nil
    ) {
        self.repository = repository
        self.selectedTab = selectedTab
        self._searchText = searchText
        self.installedSlugs = installedSlugs
        self.installedWorkflowSlugs = installedWorkflowSlugs
        self.installedMcpSlugs = installedMcpSlugs
        self.providers = providers
        self.refreshTrigger = refreshTrigger
        self.targetProvider = targetProvider
        self.onInstall = onInstall
        self.onInstallWorkflow = onInstallWorkflow
        self.onInstallMCP = onInstallMCP
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]

    private var isClawdhub: Bool {
        repository?.templateType == .clawdhub
    }

    private var normalizedSearchQuery: String {
        isClawdhub ? debouncedSearchText : ""
    }

    private var isSearching: Bool {
        let trimmed = normalizedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return isClawdhub && !trimmed.isEmpty && viewModel.isLoading
    }
    
    var body: some View {
        let repoSyncToken = watchCenter.token(for: repository)
        let searchQuery = normalizedSearchQuery
        let cacheBuster = "\(refreshTrigger)-\(repoSyncToken)-\(searchQuery)-\(retryTrigger)"
        Group {
            if repository == nil {
                ContentUnavailableView {
                    Label {
                        Text(NSLocalizedString("detail.no_repository", comment: "Select a Repository"))
                            .dsEmptyStateTitle()
                    } icon: {
                        Image(systemName: "tray")
                            .dsEmptyStateIcon()
                    }
                }
            } else if selectedTab == nil {
                ContentUnavailableView {
                    Label {
                        Text(NSLocalizedString("detail.select_tab", comment: "Select a Tab"))
                            .dsEmptyStateTitle()
                    } icon: {
                        Image(systemName: "list.bullet")
                            .dsEmptyStateIcon()
                    }
                }
            } else {
                VStack(spacing: 12) {
                    searchBar
                    contentBody
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        // 使用 .task(id:) 处理仓库切换，它会自动取消旧任务并启动新任务
        // 不需要 .onChange，避免重复触发导致请求被取消
        .task(id: "\(repository?.id ?? "")-\(selectedTab?.rawValue ?? "")-\(cacheBuster)") {
            if let repository {
                watchCenter.ensureWatching(repository: repository)
            }
            await viewModel.loadContent(for: repository, tab: selectedTab, searchQuery: searchQuery, cacheBuster: cacheBuster)
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                debouncedSearchText = newValue
            }
        }
        .sheet(item: $viewModel.selectedSkillForDetail) { skill in
            RemoteSkillDetailView(
                skill: skill,
                providers: providers,
                targetProvider: targetProvider,
                isInstalled: installedSlugs.contains(skill.slug),
                onInstall: { provider in
                    onInstall(skill, provider)
                }
            )
            .frame(minWidth: 920, idealWidth: 1100, maxWidth: .infinity,
                   minHeight: 620, idealHeight: 720, maxHeight: .infinity)
        }
        .sheet(item: $viewModel.selectedWorkflowForDetail) { workflow in
            RemoteWorkflowDetailView(
                workflow: workflow,
                providers: providers,
                targetProvider: targetProvider,
                onInstall: { provider in
                    onInstallWorkflow?(workflow, provider)
                }
            )
            .frame(minWidth: 920, idealWidth: 1100, maxWidth: .infinity,
                   minHeight: 620, idealHeight: 720, maxHeight: .infinity)
        }
        .sheet(item: $viewModel.selectedMCPForDetail) { mcp in
            RemoteMCPDetailView(
                mcp: mcp,
                providers: providers,
                targetProvider: targetProvider,
                onInstall: { provider in
                    onInstallMCP?(mcp, provider)
                }
            )
            .frame(minWidth: 920, idealWidth: 1100, maxWidth: .infinity,
                   minHeight: 620, idealHeight: 720, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if viewModel.isLoading && viewModel.skills.isEmpty && viewModel.workflows.isEmpty && viewModel.mcps.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView {
                Label {
                    Text(NSLocalizedString("remote.error.title", value: "Error Loading Data", comment: "Remote load error title"))
                        .dsEmptyStateErrorTitle()
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .dsEmptyStateIcon(color: DesignSystem.Colors.Status.error)
                }
            } description: {
                Button {
                    #if os(macOS)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(error, forType: .string)
                    #endif
                    showCopiedToast = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        showCopiedToast = false
                    }
                } label: {
                    Text(error)
                        .dsSecondaryText(font: .body)
                }
                .buttonStyle(.plain)
            } actions: {
                Button {
                    retryTrigger += 1
                } label: {
                    Text(NSLocalizedString("remote.retry", value: "Retry", comment: "Retry"))
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            gridContent
        }
    }

    private var searchBar: some View {
        HStack {
            SearchField(
                placeholder: NSLocalizedString("remote.search.placeholder", value: "Search", comment: "Search placeholder"),
                text: $searchText,
                showSearching: isSearching
            )
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var gridContent: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                skillsGrid
            }
            .padding(.horizontal)
            .padding(.bottom)
            // 彻底移除这里的 .searchable
            if showCopiedToast {
                ToastView(
                    text: NSLocalizedString("remote.error.copied", value: "Copied", comment: "Copied tooltip"),
                    systemImage: "doc.on.doc"
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showCopiedToast)
    }
    
    @ViewBuilder
    private var skillsGrid: some View {
        let shouldClientFilter = repository?.templateType != .clawdhub
        switch selectedTab {
        case .skills:
            let filtered = shouldClientFilter ? viewModel.filteredSkills(searchText: searchText) : viewModel.skills
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty
                    ? NSLocalizedString("skills.empty", comment: "No Skills")
                    : NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
                    systemImage: searchText.isEmpty ? "square.grid.2x2" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                        ? NSLocalizedString("skills.empty_desc", comment: "No skills in this repository")
                        : NSLocalizedString("remote.search.no_results_desc", value: "No matching skills found", comment: "No search results description")
                    )
                        .dsSecondaryText(font: .body)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filtered) { skill in
                            RemoteSkillCardView(
                                skill: skill,
                                isInstalled: installedSlugs.contains(skill.slug),
                                targetProvider: targetProvider,
                                providers: providers,
                                onInstall: { provider in
                                    onInstall(skill, provider)
                                },
                                onTap: {
                                    viewModel.selectedSkillForDetail = skill
                                }
                            )
                        }
                    }
                    loadMoreRowIfNeeded
                }
            }
            
        case .workflows:
            let filtered = shouldClientFilter ? viewModel.filteredWorkflows(searchText: searchText) : viewModel.workflows
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty
                    ? NSLocalizedString("remote.workflows.empty", value: "No Workflows", comment: "No workflows")
                    : NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
                    systemImage: searchText.isEmpty ? "arrow.triangle.branch" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                        ? NSLocalizedString("remote.workflows.empty_desc", value: "No workflows in this repository", comment: "No workflows description")
                        : NSLocalizedString("remote.search.no_results_desc", value: "No matching workflows found", comment: "No search results description")
                    )
                        .dsSecondaryText(font: .body)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filtered) { workflow in
                            RemoteWorkflowCardView(
                                workflow: workflow,
                                isInstalled: installedWorkflowSlugs.contains(workflow.slug),
                                targetProvider: targetProvider,
                                providers: providers,
                                onInstall: { provider in
                                    onInstallWorkflow?(workflow, provider)
                                },
                                onTap: {
                                    viewModel.selectedWorkflowForDetail = workflow
                                }
                            )
                        }
                    }
                    loadMoreRowIfNeeded
                }
            }
            
        case .mcps:
            let filtered = shouldClientFilter ? viewModel.filteredMCPs(searchText: searchText) : viewModel.mcps
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty
                    ? NSLocalizedString("remote.mcps.empty", value: "No MCPs", comment: "No MCPs")
                    : NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
                    systemImage: searchText.isEmpty ? "server.rack" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                        ? NSLocalizedString("remote.mcps.empty_desc", value: "No MCPs in this repository", comment: "No MCPs description")
                        : NSLocalizedString("remote.search.no_results_desc", value: "No matching MCPs found", comment: "No search results description")
                    )
                        .dsSecondaryText(font: .body)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filtered) { mcp in
                            RemoteMCPCardView(
                                mcp: mcp,
                                isInstalled: installedMcpSlugs.contains(mcp.slug),
                                targetProvider: targetProvider,
                                providers: providers,
                                onInstall: { provider in
                                    onInstallMCP?(mcp, provider)
                                },
                                onTap: {
                                    viewModel.selectedMCPForDetail = mcp
                                }
                            )
                        }
                    }
                    loadMoreRowIfNeeded
                }
            }
            
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var loadMoreRowIfNeeded: some View {
        if repository?.templateType != .clawdhub {
            EmptyView()
        } else if viewModel.canLoadMore {
            Button {
                Task {
                    await viewModel.loadMore(
                        repository: repository,
                        tab: selectedTab,
                        searchQuery: normalizedSearchQuery
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(
                        viewModel.isLoadingMore
                        ? NSLocalizedString("remote.load_more.loading", value: "Loading...", comment: "Loading more indicator")
                        : NSLocalizedString("remote.load_more", value: "Load More", comment: "Load more")
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoadingMore)
            .onAppear {
                guard !viewModel.isLoadingMore else { return }
                Task {
                    await viewModel.loadMore(
                        repository: repository,
                        tab: selectedTab,
                        searchQuery: normalizedSearchQuery
                    )
                }
            }
        } else if !viewModel.isLoading && !(viewModel.skills.isEmpty && viewModel.workflows.isEmpty && viewModel.mcps.isEmpty) {
            Text(NSLocalizedString("remote.load_more.end", value: "You have reached the end.", comment: "End of list"))
                .dsSecondaryText(font: .callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }
}
