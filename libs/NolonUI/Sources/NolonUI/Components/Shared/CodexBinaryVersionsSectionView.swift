import SwiftUI
import NolonUIFoundation

public struct CodexBinaryVersionsSectionView: View {
    let statusHeaderData: CodexBinaryStatusHeaderData
    let actionBarData: CodexBinaryActionBarData
    let versionTableData: CodexBinaryVersionTableData
    let onPrimaryAction: () -> Void
    let onCheckUpdates: () -> Void
    let onImportLocal: () -> Void
    let onOpenGitHub: () -> Void
    let onToggleBeta: (Bool) -> Void
    let onTapRow: (String) -> Void
    let onTapAction: (String) -> Void

    public init(
        statusHeaderData: CodexBinaryStatusHeaderData,
        actionBarData: CodexBinaryActionBarData,
        versionTableData: CodexBinaryVersionTableData,
        onPrimaryAction: @escaping () -> Void,
        onCheckUpdates: @escaping () -> Void,
        onImportLocal: @escaping () -> Void,
        onOpenGitHub: @escaping () -> Void,
        onToggleBeta: @escaping (Bool) -> Void,
        onTapRow: @escaping (String) -> Void,
        onTapAction: @escaping (String) -> Void
    ) {
        self.statusHeaderData = statusHeaderData
        self.actionBarData = actionBarData
        self.versionTableData = versionTableData
        self.onPrimaryAction = onPrimaryAction
        self.onCheckUpdates = onCheckUpdates
        self.onImportLocal = onImportLocal
        self.onOpenGitHub = onOpenGitHub
        self.onToggleBeta = onToggleBeta
        self.onTapRow = onTapRow
        self.onTapAction = onTapAction
    }

    public var body: some View {
        CodexAdvancedSectionCardView {
            CodexBinaryStatusHeaderView(data: statusHeaderData)

            CodexBinaryActionsBarView(
                data: actionBarData,
                onPrimaryAction: onPrimaryAction,
                onCheckUpdates: onCheckUpdates,
                onImportLocal: onImportLocal,
                onOpenGitHub: onOpenGitHub,
                onToggleBeta: onToggleBeta
            )

            CodexBinaryVersionTableView(
                data: versionTableData,
                onTapRow: onTapRow,
                onTapAction: onTapAction
            )
        }
    }
}
