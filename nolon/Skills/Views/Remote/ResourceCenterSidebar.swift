import SwiftUI
import NolonUI
import NolonUIFoundation

struct ResourceCenterSidebar: View {
    let title: String
    @Binding var selectedTab: ResourceContentTabType?
    let tabCounts: [ResourceContentTabType: Int]
    let hasRepository: Bool

    var body: some View {
        NolonUI.ResourceCenterSidebarComponent(
            title: title,
            selectedTab: foundationSelectedTabBinding,
            items: sidebarItems,
            showsEmptyState: !hasRepository,
            emptyTitle: NSLocalizedString("content.no_repository", comment: "Select a Repository"),
            emptyDescription: NSLocalizedString("content.no_repository_desc", comment: "Choose a repository from the sidebar")
        )
    }

    private var sidebarItems: [ResourceCenterTabItem] {
        ResourceCenterTabItem.defaults(
            counts: [
                .skills: tabCounts[.skills] ?? 0,
                .workflows: tabCounts[.workflows] ?? 0,
                .mcps: tabCounts[.mcps] ?? 0
            ]
        )
    }

    private var foundationSelectedTabBinding: Binding<ResourceCenterTabID?> {
        Binding<ResourceCenterTabID?>(
            get: { selectedTab?.foundationID },
            set: { foundationTab in
                selectedTab = foundationTab.map(ResourceContentTabType.fromFoundationID)
            }
        )
    }
}

extension ResourceContentTabType {
    var foundationID: ResourceCenterTabID {
        switch self {
        case .skills:
            return .skills
        case .workflows:
            return .workflows
        case .mcps:
            return .mcps
        }
    }

    static func fromFoundationID(_ foundationID: ResourceCenterTabID) -> Self {
        switch foundationID {
        case .skills:
            return .skills
        case .workflows:
            return .workflows
        case .mcps:
            return .mcps
        }
    }
}
