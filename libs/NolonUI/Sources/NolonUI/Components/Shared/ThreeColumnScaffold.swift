import SwiftUI

public enum ThreeColumnScaffoldMode {
    case twoColumn
    case threeColumn
}

public struct ThreeColumnSidebarWidth: Equatable {
    public let min: CGFloat
    public let ideal: CGFloat
    public let max: CGFloat

    public init(min: CGFloat, ideal: CGFloat, max: CGFloat) {
        self.min = min
        self.ideal = ideal
        self.max = max
    }
}

public struct ThreeColumnScaffold<
    Sidebar: View,
    Content: View,
    Detail: View
>: View {
    @Binding private var columnVisibility: NavigationSplitViewVisibility

    private let mode: ThreeColumnScaffoldMode
    private let sidebarWidth: ThreeColumnSidebarWidth?
    private let sidebar: () -> Sidebar
    private let content: () -> Content
    private let detail: () -> Detail

    public init(
        mode: ThreeColumnScaffoldMode,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        sidebarWidth: ThreeColumnSidebarWidth? = nil,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self._columnVisibility = columnVisibility
        self.mode = mode
        self.sidebarWidth = sidebarWidth
        self.sidebar = sidebar
        self.content = content
        self.detail = detail
    }

    public var body: some View {
        Group {
            switch mode {
            case .twoColumn:
                NavigationSplitView {
                    configuredSidebar()
                } detail: {
                    detail()
                }
            case .threeColumn:
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    configuredSidebar()
                } content: {
                    content()
                } detail: {
                    detail()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func configuredSidebar() -> AnyView {
        let base = AnyView(sidebar())
        guard let sidebarWidth else { return base }
        return AnyView(
            base.navigationSplitViewColumnWidth(
                min: sidebarWidth.min,
                ideal: sidebarWidth.ideal,
                max: sidebarWidth.max
            )
        )
    }
}

@MainActor
private struct ThreeColumnScaffoldPreviewContainer: View {
    @State private var mode: ThreeColumnScaffoldMode = .threeColumn
    @State private var visibility: NavigationSplitViewVisibility = .all

    var body: some View {
        ThreeColumnScaffold(
            mode: mode,
            columnVisibility: $visibility,
            sidebarWidth: .init(min: 180, ideal: 200, max: 240)
        ) {
            List {
                Label("Sidebar", systemImage: "sidebar.left")
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.Background.elevated)
        } content: {
            List {
                Label("Main / Codex", systemImage: "terminal")
                Label("MCP 服务器", systemImage: "server.rack")
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.Background.canvas)
        } detail: {
            Text("Detail")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.Background.canvas)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(mode == .threeColumn ? "切双栏" : "切三栏") {
                    mode = mode == .threeColumn ? .twoColumn : .threeColumn
                }
            }
        }
    }
}

#Preview {
    ThreeColumnScaffoldPreviewContainer()
}
