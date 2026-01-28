import SwiftUI
import STJSON

/// Remote 内容 Tab 类型 - 可扩展设计
enum RemoteContentTabType: String, CaseIterable, Identifiable {
    case skills = "Skills"
    case workflows = "Workflows"
    case mcps = "MCPs"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .skills: return "square.grid.2x2"
        case .workflows: return "arrow.triangle.branch"
        case .mcps: return "server.rack"
        }
    }
    
    var localizedName: String {
        switch self {
        case .skills: return NSLocalizedString("tab.skills", comment: "Skills")
        case .workflows: return NSLocalizedString("tab.workflows", comment: "Workflows")
        case .mcps: return NSLocalizedString("tab.mcps", comment: "MCPs")
        }
    }
}

/// Remote 内容 Tab 视图 ViewModel
@MainActor
@Observable
final class RemoteContentTabViewModel {
    var skillsCount: Int = 0
    var workflowsCount: Int = 0
    var mcpsCount: Int = 0
    
    func count(for tab: RemoteContentTabType) -> Int {
        switch tab {
        case .skills: return skillsCount
        case .workflows: return workflowsCount
        case .mcps: return mcpsCount
        }
    }
    
    func loadCounts(for repository: RemoteRepository?) async {
        guard let repository = repository else {
            skillsCount = 0
            workflowsCount = 0
            mcpsCount = 0
            return
        }
        
        // 加载技能数量
        do {
            switch repository.templateType {
            case .clawdhub:
                let service = ClawdhubService(baseURL: repository.baseURL)
                let skills = try await service.fetchSkills(query: nil)
                skillsCount = skills.count
                
                let workflows = try await service.fetchWorkflows(query: nil)
                workflowsCount = workflows.count
                
                let mcps = try await service.fetchMCPs(query: nil)
                mcpsCount = mcps.count
                
            case .globalSkills:
                let cacheRepo = GlobalCacheRepository()
                let skills = try await cacheRepo.fetchSkills(query: nil, limit: 100)
                skillsCount = skills.count
                
                let workflows = try await cacheRepo.fetchWorkflows(query: nil, limit: 100)
                workflowsCount = workflows.count
                
                let mcps = try await cacheRepo.fetchMCPs(query: nil, limit: 100)
                mcpsCount = mcps.count
                
            case .localFolder, .git:
                let paths = repository.effectiveSkillsPaths
                guard !paths.isEmpty else {
                    skillsCount = 0
                    workflowsCount = 0
                    mcpsCount = 0
                    return
                }
                
                if repository.templateType == .git {
                    let gitRepo = try GitRepository(repository: repository)
                    if await !(gitRepo.lastSyncDate != nil) {
                        _ = try await gitRepo.sync()
                    }
                    
                    let skills = try await gitRepo.fetchSkills(query: nil, limit: 100)
                    skillsCount = skills.count
                    
                    let workflows = try await gitRepo.fetchWorkflows(query: nil, limit: 100)
                    workflowsCount = workflows.count
                    
                    let mcps = try await gitRepo.fetchMCPs(query: nil, limit: 100)
                    mcpsCount = mcps.count
                } else {
                    let localRepo = LocalFolderRepository(
                        id: repository.id,
                        name: repository.name,
                        basePaths: paths
                    )
                    
                    let skills = try await localRepo.fetchSkills(query: nil, limit: 100)
                    skillsCount = skills.count
                    
                    let workflows = try await localRepo.fetchWorkflows(query: nil, limit: 100)
                    workflowsCount = workflows.count
                    
                    let mcps = try await localRepo.fetchMCPs(query: nil, limit: 100)
                    mcpsCount = mcps.count
                }
            }
        } catch {
            print("Failed to count skills: \(error)")
            skillsCount = 0
            workflowsCount = 0
            mcpsCount = 0
        }
    }
}

/// 中间栏 - Remote 内容导航列表 (类似 ProviderContentTabView)
struct RemoteContentTabView: View {
    let repository: RemoteRepository?
    @Binding var selectedTab: RemoteContentTabType?
    var refreshTrigger: Int
    
    @State private var viewModel = RemoteContentTabViewModel()
    
    var body: some View {
        Group {
            if let repository = repository {
                List(selection: $selectedTab) {
                    ForEach(RemoteContentTabType.allCases) { tab in
                        HStack {
                            Label(tab.localizedName, systemImage: tab.icon)
                            Spacer()
                            Text("\(viewModel.count(for: tab))")
                                .foregroundStyle(.secondary)
                        }
                        .tag(tab)
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle(repository.name)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("content.no_repository", comment: "Select a Repository"),
                    systemImage: "tray",
                    description: Text(NSLocalizedString("content.no_repository_desc", comment: "Choose a repository from the sidebar"))
                )
            }
        }
        .onAppear {
            if selectedTab == nil {
                selectedTab = .skills
            }
        }
        .task(id: "\(repository?.id ?? "")-\(refreshTrigger)") {
            await viewModel.loadCounts(for: repository)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
    }
}
