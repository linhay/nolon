import SwiftUI
import Observation

/// Remote Skills Grid ViewModel
@MainActor
@Observable
final class RemoteSkillsGridViewModel {
    var skills: [RemoteSkill] = []
    var isLoading = false
    var errorMessage: String?
    var selectedSkillForDetail: RemoteSkill?
    
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
    
    func loadSkills(for repository: RemoteRepository?) async {
        guard let repository = repository else {
            skills = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
                let paths = repository.effectiveSkillsPaths
                guard !paths.isEmpty else {
                    throw LocalFolderError.pathNotFound("No path configured")
                }
                
                if repository.templateType == .git {
                    let gitService = GitRepositoryService.shared
                    if await !gitService.isCloned(repository) {
                        let result = try await gitService.syncRepository(repository)
                        if !result.success {
                            throw LocalFolderError.cannotReadDirectory(result.message)
                        }
                    }
                }
                
                let localService = LocalFolderService()
                skills = try await localService.fetchSkills(fromPaths: paths)
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
    let providers: [Provider]
    var refreshTrigger: Int
    let targetProvider: Provider?
    let onInstall: (RemoteSkill, Provider) -> Void
    
    @State private var viewModel = RemoteSkillsGridViewModel()
    
    init(
        repository: RemoteRepository?,
        selectedTab: RemoteContentTabType?,
        searchText: String,
        installedSlugs: Set<String>,
        providers: [Provider],
        refreshTrigger: Int,
        targetProvider: Provider?,
        onInstall: @escaping (RemoteSkill, Provider) -> Void
    ) {
        self.repository = repository
        self.selectedTab = selectedTab
        self.searchText = searchText
        self.installedSlugs = installedSlugs
        self.providers = providers
        self.refreshTrigger = refreshTrigger
        self.targetProvider = targetProvider
        self.onInstall = onInstall
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
                if viewModel.isLoading && viewModel.skills.isEmpty {
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
        .task(id: "\(repository?.id ?? "")-\(refreshTrigger)") {
            await viewModel.loadSkills(for: repository)
        }
        .onChange(of: repository) { _, newRepository in
            Task {
                await viewModel.loadSkills(for: newRepository)
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
        let filtered = viewModel.filteredSkills(searchText: searchText)
        
        switch selectedTab {
        case .skills:
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
        case .none:
            EmptyView()
        }
    }
}

