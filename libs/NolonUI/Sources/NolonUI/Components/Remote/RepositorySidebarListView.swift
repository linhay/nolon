import SwiftUI
import NolonUIFoundation

public struct RepositorySidebarListView<RowContextMenu: View>: View {
    @Binding var selectedRowID: String?

    let sections: [RepositorySidebarSectionData]
    let collapsedSectionIDs: Set<String>
    let bottomPadding: CGFloat
    let onToggleSection: (String) -> Void
    let onDeleteRows: (String, IndexSet) -> Void
    let rowContextMenu: (RepositorySidebarRowData) -> RowContextMenu

    public init(
        selectedRowID: Binding<String?>,
        sections: [RepositorySidebarSectionData],
        collapsedSectionIDs: Set<String>,
        bottomPadding: CGFloat = 52,
        onToggleSection: @escaping (String) -> Void,
        onDeleteRows: @escaping (String, IndexSet) -> Void,
        @ViewBuilder rowContextMenu: @escaping (RepositorySidebarRowData) -> RowContextMenu
    ) {
        self._selectedRowID = selectedRowID
        self.sections = sections
        self.collapsedSectionIDs = collapsedSectionIDs
        self.bottomPadding = bottomPadding
        self.onToggleSection = onToggleSection
        self.onDeleteRows = onDeleteRows
        self.rowContextMenu = rowContextMenu
    }

    public var body: some View {
        List(selection: $selectedRowID) {
            ForEach(sections) { section in
                Section {
                    RepositorySidebarSectionToggleRow(
                        title: section.title,
                        isCollapsed: collapsedSectionIDs.contains(section.id)
                    ) {
                        onToggleSection(section.id)
                    }

                    if !collapsedSectionIDs.contains(section.id) {
                        ForEach(section.rows) { row in
                            RepositorySidebarRowView(data: row)
                                .tag(Optional(row.id))
                                .contextMenu {
                                    rowContextMenu(row)
                                }
                        }
                        .onDelete { offsets in
                            onDeleteRows(section.id, offsets)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .animation(.snappy(duration: 0.2), value: collapsedSectionIDs)
        .padding(.bottom, bottomPadding)
    }
}
