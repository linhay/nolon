import SwiftUI
import NolonUIFoundation

public struct ProviderSidebarComponent: View {
    @Binding private var selectedItemKey: String?

    private let sections: [SidebarSection]
    private let toolItems: [SidebarToolItem]
    private let style: ProviderSidebarStyle

    private let providerDebugLocatorText: (SidebarProviderItem) -> String?
    private let onShowInFinder: (SidebarProviderItem) -> Void
    private let onViewOfficialDocumentation: (SidebarProviderItem) -> Void
    private let onEdit: (SidebarProviderItem) -> Void
    private let onDeleteProvider: (SidebarProviderItem) -> Void
    private let onDeleteOffsets: (SidebarSection, IndexSet) -> Void
    private let onMove: (SidebarSection, IndexSet, Int) -> Void
    private let onAddProvider: () -> Void
    private let onCopyDebugMarker: (String) -> Void

    public init(
        selectedItemKey: Binding<String?>,
        sections: [SidebarSection],
        toolItems: [SidebarToolItem] = SidebarToolItem.default,
        style: ProviderSidebarStyle = .default,
        providerDebugLocatorText: @escaping (SidebarProviderItem) -> String? = { _ in nil },
        onShowInFinder: @escaping (SidebarProviderItem) -> Void,
        onViewOfficialDocumentation: @escaping (SidebarProviderItem) -> Void,
        onEdit: @escaping (SidebarProviderItem) -> Void,
        onDeleteProvider: @escaping (SidebarProviderItem) -> Void,
        onDeleteOffsets: @escaping (SidebarSection, IndexSet) -> Void,
        onMove: @escaping (SidebarSection, IndexSet, Int) -> Void,
        onAddProvider: @escaping () -> Void,
        onCopyDebugMarker: @escaping (String) -> Void = { _ in }
    ) {
        self._selectedItemKey = selectedItemKey
        self.sections = sections
        self.toolItems = toolItems
        self.style = style
        self.providerDebugLocatorText = providerDebugLocatorText
        self.onShowInFinder = onShowInFinder
        self.onViewOfficialDocumentation = onViewOfficialDocumentation
        self.onEdit = onEdit
        self.onDeleteProvider = onDeleteProvider
        self.onDeleteOffsets = onDeleteOffsets
        self.onMove = onMove
        self.onAddProvider = onAddProvider
        self.onCopyDebugMarker = onCopyDebugMarker
    }

    public var body: some View {
        List(selection: $selectedItemKey) {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        SidebarProviderRowView(
                            item: item,
                            style: style,
                            providerDebugLocatorText: providerDebugLocatorText,
                            onShowInFinder: onShowInFinder,
                            onViewOfficialDocumentation: onViewOfficialDocumentation,
                            onEdit: onEdit,
                            onDeleteProvider: onDeleteProvider,
                            onCopyDebugMarker: onCopyDebugMarker
                        )
                            .tag(SidebarSelectionKey.provider(item.id).rawValue)
                    }
                    .onDelete { offsets in
                        onDeleteOffsets(section, offsets)
                    }
                    .onMove { source, destination in
                        onMove(section, source, destination)
                    }
                } header: {
                    SidebarSectionHeaderView(
                        title: NSLocalizedString(
                            section.titleKey,
                            value: section.fallbackTitle,
                            comment: "Sidebar provider section title"
                        ),
                        style: style
                    )
                }
            }

            Section {
                ForEach(toolItems) { tool in
                    SidebarToolRowView(item: tool)
                }
            } header: {
                SidebarSectionHeaderView(
                    title: NSLocalizedString("sidebar.section.tools", value: "Tools", comment: "Sidebar tools section title"),
                    style: style
                )
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(NSLocalizedString("app.title", value: "nolon", comment: "App title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onAddProvider()
                } label: {
                    Label(
                        NSLocalizedString("action.add_provider", value: "Add Provider", comment: "Add provider action"),
                        systemImage: "plus"
                    )
                }
            }
        }
    }

}

@MainActor
private struct ProviderSidebarComponentPreviewContainer: View {
    @State private var selectedItemKey: String? = SidebarSelectionKey.provider("preview-codex").rawValue

    private static let sampleProviders: [SidebarProviderInput] = [
        .init(
            id: "preview-codex",
            kind: .vendor,
            vendorCategory: .original,
            name: "Codex",
            subtitle: "/tmp/preview/.codex/skills",
            iconName: "terminal",
            hasDocumentation: true
        ),
        .init(
            id: "preview-claude",
            kind: .vendor,
            vendorCategory: .integrated,
            name: "Claude Code",
            subtitle: "/tmp/preview/.claude/skills",
            iconName: "message",
            hasDocumentation: true
        ),
        .init(
            id: "preview-project",
            kind: .project,
            vendorCategory: nil,
            name: "My Project",
            subtitle: "/tmp/preview/project/.codex/skills",
            iconName: "folder",
            hasDocumentation: false
        )
    ]

    private var sections: [SidebarSection] {
        SidebarSectionBuilder.buildSections(providers: Self.sampleProviders)
    }

    var body: some View {
        NavigationStack {
            ProviderSidebarComponent(
                selectedItemKey: $selectedItemKey,
                sections: sections,
                onShowInFinder: { _ in },
                onViewOfficialDocumentation: { _ in },
                onEdit: { _ in },
                onDeleteProvider: { _ in },
                onDeleteOffsets: { _, _ in },
                onMove: { _, _, _ in },
                onAddProvider: {}
            )
        }
    }
}

#Preview("Provider Sidebar Component") {
    ProviderSidebarComponentPreviewContainer()
        .frame(width: 280, height: 520)
}
