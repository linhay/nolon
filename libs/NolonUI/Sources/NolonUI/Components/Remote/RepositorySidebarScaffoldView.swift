import SwiftUI
import NolonUIFoundation

public struct RepositorySidebarScaffoldView<RowContextMenu: View>: View {
    let showsHeader: Bool
    let sheetTitle: String
    let sidebarTitle: String?
    @Binding var selectedRowID: String?
    let sections: [RepositorySidebarSectionData]
    let collapsedSectionIDs: Set<String>
    let addButtonTitle: String
    let isSyncing: Bool
    let syncingRepositoryName: String?
    let syncCompletionMessage: String?
    let syncCompletionRepositoryName: String?
    let syncCompletionTone: SyncHUDTone
    let onToggleSection: (String) -> Void
    let onDeleteRows: (String, IndexSet) -> Void
    let onTapAddButton: () -> Void
    let rowContextMenu: (RepositorySidebarRowData) -> RowContextMenu

    public init(
        showsHeader: Bool = true,
        sheetTitle: String = NSLocalizedString("Sources", comment: "Sources"),
        sidebarTitle: String? = nil,
        selectedRowID: Binding<String?>,
        sections: [RepositorySidebarSectionData],
        collapsedSectionIDs: Set<String>,
        addButtonTitle: String = NSLocalizedString("Add Repository", comment: "Add Repository"),
        isSyncing: Bool,
        syncingRepositoryName: String?,
        syncCompletionMessage: String?,
        syncCompletionRepositoryName: String?,
        syncCompletionTone: SyncHUDTone,
        onToggleSection: @escaping (String) -> Void,
        onDeleteRows: @escaping (String, IndexSet) -> Void,
        onTapAddButton: @escaping () -> Void,
        @ViewBuilder rowContextMenu: @escaping (RepositorySidebarRowData) -> RowContextMenu
    ) {
        self.showsHeader = showsHeader
        self.sheetTitle = sheetTitle
        self.sidebarTitle = sidebarTitle
        self._selectedRowID = selectedRowID
        self.sections = sections
        self.collapsedSectionIDs = collapsedSectionIDs
        self.addButtonTitle = addButtonTitle
        self.isSyncing = isSyncing
        self.syncingRepositoryName = syncingRepositoryName
        self.syncCompletionMessage = syncCompletionMessage
        self.syncCompletionRepositoryName = syncCompletionRepositoryName
        self.syncCompletionTone = syncCompletionTone
        self.onToggleSection = onToggleSection
        self.onDeleteRows = onDeleteRows
        self.onTapAddButton = onTapAddButton
        self.rowContextMenu = rowContextMenu
    }

    public var body: some View {
        SidebarHeaderScaffold(
            showsSheetHeader: showsHeader,
            sheetTitle: sheetTitle,
            sidebarTitle: sidebarTitle
        ) {
            RepositorySidebarListView(
                selectedRowID: $selectedRowID,
                sections: sections,
                collapsedSectionIDs: collapsedSectionIDs,
                onToggleSection: onToggleSection,
                onDeleteRows: onDeleteRows,
                rowContextMenu: rowContextMenu
            )
        }
        .bottomTrailingOverlay(isPresented: true, trailing: 12, bottom: 12) {
            RepositoryFloatingAddButton(
                title: addButtonTitle,
                action: onTapAddButton
            )
        }
        .overlay(alignment: .top) {
            RepositorySyncHUDOverlay(
                isSyncing: isSyncing,
                syncingRepositoryName: syncingRepositoryName,
                completionMessage: syncCompletionMessage,
                completionRepositoryName: syncCompletionRepositoryName,
                completionTone: syncCompletionTone
            )
        }
    }
}
