import SwiftUI
import STJSON

/// Remote 内容 Tab 类型 - 可扩展设计
enum RemoteContentTabType: String, CaseIterable, Identifiable {
    case skills = "Skills"
    // 未来可扩展:
    // case workflows = "Workflows"
    // case templates = "Templates"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .skills: return "square.grid.2x2"
        }
    }
    
    var localizedName: String {
        switch self {
        case .skills: return NSLocalizedString("tab.skills", comment: "Skills")
        }
    }
}

/// Remote 内容 Tab 视图 ViewModel
@MainActor
@Observable
final class RemoteContentTabViewModel {
    var skillsCount: Int = 0
    
    func count(for tab: RemoteContentTabType) -> Int {
        switch tab {
        case .skills: return skillsCount
        }
    }
    
    func loadCounts(for repository: RemoteRepository?) async {
        guard let repository = repository else {
            skillsCount = 0
            return
        }
        
        // 加载技能数量
        do {
                let paths = repository.effectiveSkillsPaths
                guard !paths.isEmpty else {
                    skillsCount = 0
                    return
                }
                
                if repository.templateType == .git {
                    let gitService = GitRepositoryService.shared
                    if await !gitService.isCloned(repository) {
                        let result = try await gitService.syncRepository(repository)
                        if !result.success {
                            skillsCount = 0
                            return
                        }
                    }
                }
                
                let localService = LocalFolderService()
                let skills = try await localService.fetchSkills(fromPaths: paths)
                skillsCount = skills.count
        } catch {
            print("Failed to count skills: \(error)")
            skillsCount = 0
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
