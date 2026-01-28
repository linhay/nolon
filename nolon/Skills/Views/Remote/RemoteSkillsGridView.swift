import SwiftUI
import Observation

/// Remote Skills Grid ViewModel
@MainActor
@Observable
final class RemoteSkillsGridViewModel {
    var skills: [RemoteSkill] = []
    var workflows: [RemoteWorkflow] = []
    var mcps: [RemoteMCP] = []
    var isLoading = false
    var errorMessage: String?
    var selectedSkillForDetail: RemoteSkill?
    var selectedWorkflowForDetail: RemoteWorkflow?
    var selectedMCPForDetail: RemoteMCP?
    
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
    
    func loadContent(for repository: RemoteRepository?, tab: RemoteContentTabType?) async {
        guard let repository = repository, let tab = tab else {
            skills = []
            workflows = []
            mcps = []
            return
        }
        
        // 切换仓库时立即清空旧数据，确保每个仓库显示独立的数据
        isLoading = true
        errorMessage = nil
        
        do {
            switch repository.templateType {
            case .clawdhub:
                let repo = ClawdhubRepository(repository: repository)
                switch tab {
                case .skills:
                    skills = try await repo.fetchSkills(query: nil, limit: 20)
                case .workflows:
                    workflows = try await repo.fetchWorkflows(query: nil, limit: 20)
                case .mcps:
                    mcps = try await repo.fetchMCPs(query: nil, limit: 20)
                }
                
            case .globalSkills:
                // Use GlobalCacheRepository for global cache
                let cacheRepo = GlobalCacheRepository()
                
                switch tab {
                case .skills:
                    skills = try await cacheRepo.fetchSkills(query: nil, limit: 100)
                case .workflows:
                    workflows = try await cacheRepo.fetchWorkflows(query: nil, limit: 100)
                case .mcps:
                    mcps = try await cacheRepo.fetchMCPs(query: nil, limit: 100)
                }
                
            case .localFolder, .git:
                let paths = repository.effectiveSkillsPaths
                guard !paths.isEmpty else {
                    throw RepositoryError.invalidConfiguration
                }
                
                if repository.templateType == .git {
                    let gitRepo = try GitRepository(repository: repository)
                    // Sync if needed
                    if await !(gitRepo.lastSyncDate != nil) {
                        _ = try await gitRepo.sync()
                    }
                    
                    switch tab {
                    case .skills:
                        skills = try await gitRepo.fetchSkills(query: nil, limit: 100)
                    case .workflows:
                        workflows = try await gitRepo.fetchWorkflows(query: nil, limit: 100)
                    case .mcps:
                        mcps = try await gitRepo.fetchMCPs(query: nil, limit: 100)
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
                        skills = try await localRepo.fetchSkills(query: nil, limit: 100)
                    case .workflows:
                        workflows = try await localRepo.fetchWorkflows(query: nil, limit: 100)
                    case .mcps:
                        mcps = try await localRepo.fetchMCPs(query: nil, limit: 100)
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
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

/// Detail 区域 - Grid 布局显示远程技能
struct RemoteSkillsGridView: View {
    let repository: RemoteRepository?
    let selectedTab: RemoteContentTabType?
    let searchText: String
    let installedSlugs: Set<String>
    let installedWorkflowSlugs: Set<String>
    let providers: [Provider]
    var refreshTrigger: Int
    let targetProvider: Provider?
    let onInstall: (RemoteSkill, Provider) -> Void
    let onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)?
    let onInstallMCP: ((RemoteMCP, Provider) -> Void)?
    
    @State private var viewModel = RemoteSkillsGridViewModel()
    
    init(
        repository: RemoteRepository?,
        selectedTab: RemoteContentTabType?,
        searchText: String,
        installedSlugs: Set<String>,
        installedWorkflowSlugs: Set<String>,
        providers: [Provider],
        refreshTrigger: Int,
        targetProvider: Provider?,
        onInstall: @escaping (RemoteSkill, Provider) -> Void,
        onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)? = nil,
        onInstallMCP: ((RemoteMCP, Provider) -> Void)? = nil
    ) {
        self.repository = repository
        self.selectedTab = selectedTab
        self.searchText = searchText
        self.installedSlugs = installedSlugs
        self.installedWorkflowSlugs = installedWorkflowSlugs
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
    
    var body: some View {
        Group {
            if repository == nil {
                ContentUnavailableView(
                    NSLocalizedString("detail.no_repository", comment: "Select a Repository"),
                    systemImage: "tray"
                )
            } else if selectedTab == nil {
                ContentUnavailableView(
                    NSLocalizedString("detail.select_tab", comment: "Select a Tab"),
                    systemImage: "list.bullet"
                )
            } else {
                if viewModel.isLoading && viewModel.skills.isEmpty && viewModel.workflows.isEmpty && viewModel.mcps.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Error Loading Data",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    gridContent
                }
            }
        }
        // 使用 .task(id:) 处理仓库切换，它会自动取消旧任务并启动新任务
        // 不需要 .onChange，避免重复触发导致请求被取消
        .task(id: "\(repository?.id ?? "")-\(selectedTab?.rawValue ?? "")-\(refreshTrigger)") {
            await viewModel.loadContent(for: repository, tab: selectedTab)
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
            .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
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
            .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
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
            .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var gridContent: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                skillsGrid
            }
            .padding()
            // 彻底移除这里的 .searchable
        }
    }
    
    @ViewBuilder
    private var skillsGrid: some View {
        switch selectedTab {
        case .skills:
            let filtered = viewModel.filteredSkills(searchText: searchText)
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? NSLocalizedString("skills.empty", comment: "No Skills") : "No Results",
                    systemImage: searchText.isEmpty ? "square.grid.2x2" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? NSLocalizedString("skills.empty_desc", comment: "No skills in this repository") : "No matching skills found")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
            }
            
        case .workflows:
            let filtered = viewModel.filteredWorkflows(searchText: searchText)
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Workflows" : "No Results",
                    systemImage: searchText.isEmpty ? "arrow.triangle.branch" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "No workflows in this repository" : "No matching workflows found")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
            }
            
        case .mcps:
            let filtered = viewModel.filteredMCPs(searchText: searchText)
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No MCPs" : "No Results",
                    systemImage: searchText.isEmpty ? "server.rack" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "No MCPs in this repository" : "No matching MCPs found")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filtered) { mcp in
                        RemoteMCPCardView(
                            mcp: mcp,
                            isInstalled: false, // TODO: Track MCP installation status
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
            }
            
        case .none:
            EmptyView()
        }
    }
}
