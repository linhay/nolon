import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI
import NolonUIFoundation

/// 中间栏 - 资源中心内容导航列表 (类似 ProviderContentTabView)
struct ResourceCenterTabView: View, DebugPageLocatable {
    let repository: RemoteRepository?
    @Binding var selectedTab: ResourceCenterTabID?
    var refreshTrigger: Int
    
    @State private var viewModel = ResourceCenterTabViewModel()
    private var watchCenter = RemoteRepositoryWatchCenter.shared

    init(
        repository: RemoteRepository?,
        selectedTab: Binding<ResourceCenterTabID?>,
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
        NolonUI.ResourceCenterSidebarComponent(
            title: repository?.name,
            selectedTab: $selectedTab,
            items: sidebarItems,
            showsEmptyState: repository == nil
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

    private var sidebarItems: [ResourceCenterTabItem] {
        ResourceCenterTabItem.defaults(
            counts: [
                .skills: viewModel.skillsCount,
                .workflows: viewModel.workflowsCount,
                .mcps: viewModel.mcpsCount,
                .agents: viewModel.agentsCount
            ]
        )
    }
}
