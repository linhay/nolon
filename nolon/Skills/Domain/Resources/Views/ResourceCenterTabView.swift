import SwiftUI
import ProviderCatalog
import NolonResourceKit

/// 资源中心内容 Tab 类型 - 可扩展设计
enum ResourceContentTabType: String, CaseIterable, Identifiable {
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

/// 资源中心内容 Tab 视图 ViewModel
@MainActor
@Observable
final class ResourceCenterTabViewModel {
    var skillsCount: Int = 0
    var workflowsCount: Int = 0
    var mcpsCount: Int = 0
    private let countService = RemoteRepositoryCountService()
    
    func count(for tab: ResourceContentTabType) -> Int {
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

/// 中间栏 - 资源中心内容导航列表 (类似 ProviderContentTabView)
struct ResourceCenterTabView: View, DebugPageLocatable {
    let repository: RemoteRepository?
    @Binding var selectedTab: ResourceContentTabType?
    var refreshTrigger: Int
    
    @State private var viewModel = ResourceCenterTabViewModel()
    private var watchCenter = RemoteRepositoryWatchCenter.shared

    init(
        repository: RemoteRepository?,
        selectedTab: Binding<ResourceContentTabType?>,
        refreshTrigger: Int
    ) {
        self.repository = repository
        self._selectedTab = selectedTab
        self.refreshTrigger = refreshTrigger
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        var items = [PageMarkerItem(title: "Resource Center Sidebar")]
        if let selectedTab {
            items.append(PageMarkerItem(title: selectedTab.localizedName))
        }
        return items
    }
    
    var body: some View {
        let repoSyncToken = watchCenter.token(for: repository)
        let cacheBuster = "\(refreshTrigger)-\(repoSyncToken)"
        ResourceCenterSidebar(
            title: repository?.name ?? NSLocalizedString("resource.center.title", value: "Resource Center", comment: "Resource center title"),
            selectedTab: $selectedTab,
            tabCounts: [
                .skills: viewModel.skillsCount,
                .workflows: viewModel.workflowsCount,
                .mcps: viewModel.mcpsCount
            ],
            hasRepository: repository != nil
        )
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
        .debugPageMarkerContextMenu(debugPageMarkerItems, withDivider: false) {
            EmptyView()
        }
        .debugPageLocator(debugPageMarkerItems)
    }
}
