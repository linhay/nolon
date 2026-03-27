import SwiftUI
import NolonUIFoundation

public enum ResourceCenterSidebarMetrics {
    public static let headerHeight: CGFloat = SidebarColumnMetrics.headerHeight
    public static let headerHorizontalPadding: CGFloat = SidebarColumnMetrics.headerHorizontalPadding
    public static let columnMinWidth: CGFloat = SidebarColumnMetrics.columnMinWidth
    public static let columnIdealWidth: CGFloat = SidebarColumnMetrics.columnIdealWidth
    public static let columnMaxWidth: CGFloat = SidebarColumnMetrics.columnMaxWidth
}

public struct ResourceCenterSidebarComponent: View {
    @Binding private var selectedTab: ResourceCenterTabID?

    private let title: String
    private let items: [ResourceCenterTabItem]
    private let showsEmptyState: Bool
    private let emptyTitle: String
    private let emptyDescription: String
    private let emptySystemImage: String

    public init(
        title: String? = nil,
        selectedTab: Binding<ResourceCenterTabID?>,
        items: [ResourceCenterTabItem],
        showsEmptyState: Bool,
        emptyTitle: String = NSLocalizedString(
            "content.no_repository",
            comment: "Select a Repository"
        ),
        emptyDescription: String = NSLocalizedString(
            "content.no_repository_desc",
            comment: "Choose a repository from the sidebar"
        ),
        emptySystemImage: String = "tray"
    ) {
        self.title = title ?? NSLocalizedString(
            "resource.center.title",
            value: "Resource Center",
            comment: "Resource center title"
        )
        self._selectedTab = selectedTab
        self.items = items
        self.showsEmptyState = showsEmptyState
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.emptySystemImage = emptySystemImage
    }

    public var body: some View {
        SidebarColumnScaffold(title: title) {
            if showsEmptyState {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptySystemImage,
                    description: Text(emptyDescription)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                )
            } else {
                List(selection: $selectedTab) {
                    ForEach(items) { item in
                        HStack {
                            Label(
                                NSLocalizedString(
                                    item.titleKey,
                                    value: item.fallbackTitle,
                                    comment: "Resource center tab title"
                                ),
                                systemImage: item.iconName
                            )
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                .font(.callout)
                        }
                        .tag(item.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

@MainActor
private struct ResourceCenterSidebarComponentPreviewContainer: View {
    @State private var selectedTab: ResourceCenterTabID? = .skills

    var body: some View {
        NavigationStack {
            ResourceCenterSidebarComponent(
                title: "Resource Center",
                selectedTab: $selectedTab,
                items: ResourceCenterTabItem.defaults(
                    counts: [.skills: 13, .workflows: 4, .mcps: 2]
                ),
                showsEmptyState: false,
                emptyTitle: "Select a Repository",
                emptyDescription: "Choose a repository from the sidebar"
            )
        }
    }
}

#Preview("Resource Center Sidebar") {
    ResourceCenterSidebarComponentPreviewContainer()
        .frame(width: 220, height: 520)
}
