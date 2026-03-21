import SwiftUI
import NolonUIFoundation

public enum ResourceCenterSidebarMetrics {
    public static let headerHeight: CGFloat = 52
    public static let headerHorizontalPadding: CGFloat = 16
    public static let columnMinWidth: CGFloat = 160
    public static let columnIdealWidth: CGFloat = 180
    public static let columnMaxWidth: CGFloat = 200
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
        title: String,
        selectedTab: Binding<ResourceCenterTabID?>,
        items: [ResourceCenterTabItem],
        showsEmptyState: Bool,
        emptyTitle: String,
        emptyDescription: String,
        emptySystemImage: String = "tray"
    ) {
        self.title = title
        self._selectedTab = selectedTab
        self.items = items
        self.showsEmptyState = showsEmptyState
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.emptySystemImage = emptySystemImage
    }

    public var body: some View {
        VStack(spacing: 0) {
            compactHeader
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
        .navigationSplitViewColumnWidth(
            min: ResourceCenterSidebarMetrics.columnMinWidth,
            ideal: ResourceCenterSidebarMetrics.columnIdealWidth,
            max: ResourceCenterSidebarMetrics.columnMaxWidth
        )
    }

    private var compactHeader: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(height: ResourceCenterSidebarMetrics.headerHeight)
        .padding(.horizontal, ResourceCenterSidebarMetrics.headerHorizontalPadding)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Component.separator)
                .frame(height: 1)
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
