import SwiftUI

public enum ProviderContentTabSidebarMetrics {
    public static let headerHeight: CGFloat = SidebarColumnMetrics.headerHeight
    public static let headerHorizontalPadding: CGFloat = SidebarColumnMetrics.headerHorizontalPadding
    public static let columnMinWidth: CGFloat = SidebarColumnMetrics.columnMinWidth
    public static let columnIdealWidth: CGFloat = SidebarColumnMetrics.columnIdealWidth
    public static let columnMaxWidth: CGFloat = SidebarColumnMetrics.columnMaxWidth
}

public struct ProviderContentTabSidebarItem<Tab: Hashable>: Identifiable, Hashable {
    public let id: Tab
    public let title: String
    public let iconName: String
    public let countText: String?
    public let trailingSymbolName: String?
    public let trailingHelpText: String?

    public init(
        id: Tab,
        title: String,
        iconName: String,
        countText: String? = nil,
        trailingSymbolName: String? = nil,
        trailingHelpText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.countText = countText
        self.trailingSymbolName = trailingSymbolName
        self.trailingHelpText = trailingHelpText
    }
}

public struct ProviderContentTabSidebarComponent<Tab: Hashable>: View {
    @Binding private var selectedTab: Tab?

    private let providerTitle: String?
    private let items: [ProviderContentTabSidebarItem<Tab>]
    private let emptyTitle: String
    private let emptyDescription: String
    private let emptySystemImage: String
    private let onTapTrailingAccessory: ((Tab) -> Void)?

    public init(
        selectedTab: Binding<Tab?>,
        providerTitle: String?,
        items: [ProviderContentTabSidebarItem<Tab>],
        emptyTitle: String = "Select a Provider",
        emptyDescription: String = "Choose a provider from the sidebar",
        emptySystemImage: String = "sidebar.left",
        onTapTrailingAccessory: ((Tab) -> Void)? = nil
    ) {
        self._selectedTab = selectedTab
        self.providerTitle = providerTitle
        self.items = items
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.emptySystemImage = emptySystemImage
        self.onTapTrailingAccessory = onTapTrailingAccessory
    }

    public var body: some View {
        VStack(spacing: 0) {
            SidebarColumnHeader(title: providerTitle ?? emptyTitle)

            Group {
                if providerTitle != nil {
                    List(selection: $selectedTab) {
                        ForEach(items) { item in
                            HStack {
                                Label(item.title, systemImage: item.iconName)
                                Spacer()

                                if let symbolName = item.trailingSymbolName {
                                    Button {
                                        onTapTrailingAccessory?(item.id)
                                    } label: {
                                        Image(systemName: symbolName)
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help(item.trailingHelpText ?? "")
                                }

                                if let countText = item.countText {
                                    Text(countText)
                                        .dsSecondaryText(font: .callout)
                                }
                            }
                            .tag(item.id)
                        }
                    }
                    .listStyle(.sidebar)
                } else {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: emptySystemImage,
                        description: Text(emptyDescription)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    )
                }
            }
        }
        .navigationSplitViewColumnWidth(
            min: ProviderContentTabSidebarMetrics.columnMinWidth,
            ideal: ProviderContentTabSidebarMetrics.columnIdealWidth,
            max: ProviderContentTabSidebarMetrics.columnMaxWidth
        )
    }
}

@MainActor
private struct ProviderContentTabSidebarComponentPreviewContainer: View {
    private enum PreviewTab: String, CaseIterable, Hashable {
        case skills
        case workflows
        case mcp
        case advanced
    }

    @State private var selectedTab: PreviewTab? = .skills

    var body: some View {
        HStack(spacing: 0) {
            ProviderContentTabSidebarComponent(
                selectedTab: $selectedTab,
                providerTitle: "Codex",
                items: [
                    .init(id: .skills, title: "Skills", iconName: "square.grid.2x2", countText: "12"),
                    .init(id: .workflows, title: "Workflows", iconName: "arrow.triangle.branch", countText: "3"),
                    .init(id: .mcp, title: "MCP", iconName: "server.rack", countText: "2"),
                    .init(
                        id: .advanced,
                        title: "Advanced",
                        iconName: "slider.horizontal.3",
                        trailingSymbolName: "arrow.up.right.square",
                        trailingHelpText: "View Official Documentation"
                    )
                ]
            )
        }
    }
}

#Preview("Provider Content Tab Sidebar Component") {
    ProviderContentTabSidebarComponentPreviewContainer()
        .frame(width: 560, height: 360)
}
