import SwiftUI
import ProviderCatalog
import NolonResourceKit

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
    private let countService = RemoteRepositoryCountService()
    
    func count(for tab: RemoteContentTabType) -> Int {
        switch tab {
        case .skills: return skillsCount
        case .workflows: return workflowsCount
        case .mcps: return mcpsCount
        }
    }
    
    func loadCounts(for repository: RemoteRepository?) async {
        let counts = await countService.countAll(repository: repository, limit: 100)
        skillsCount = counts.skills
        workflowsCount = counts.workflows
        mcpsCount = counts.mcps
    }
}

/// 中间栏 - Remote 内容导航列表 (类似 ProviderContentTabView)
struct RemoteContentTabView: View {
    let repository: RemoteRepository?
    @Binding var selectedTab: RemoteContentTabType?
    var refreshTrigger: Int
    
    @State private var viewModel = RemoteContentTabViewModel()
    @ObservedObject private var watchCenter = RemoteRepositoryWatchCenter.shared
    
    var body: some View {
        let repoSyncToken = watchCenter.token(for: repository)
        let cacheBuster = "\(refreshTrigger)-\(repoSyncToken)"
        Group {
            if let repository = repository {
                List(selection: $selectedTab) {
                    ForEach(RemoteContentTabType.allCases) { tab in
                        HStack {
                            Label(tab.localizedName, systemImage: tab.icon)
                            Spacer()
                            Text("\(viewModel.count(for: tab))")
                                .dsSecondaryText(font: .callout)
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
                        .dsSecondaryText(font: .body)
                )
            }
        }
        .onAppear {
            if selectedTab == nil {
                selectedTab = .skills
            }
        }
        .task(id: "\(repository?.id ?? "")-\(cacheBuster)") {
            if let repository {
                watchCenter.ensureWatching(repository: repository)
            }
            await viewModel.loadCounts(for: repository)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
    }
}
