import SwiftUI
import Observation
import Foundation
import ProviderUsage
import NolonUIFoundation
import NolonUI

struct CodexImportSheet: View {
    static func minimumSheetHeight(hasAnyCandidates: Bool) -> CGFloat {
        hasAnyCandidates ? 560 : 320
    }

    @Bindable var viewModel: ProviderUsageCodexImportSheetViewModel
    let onCancel: () -> Void

    private var selectedCount: Int {
        viewModel.sections.flatMap(\.items).filter { $0.validation.isValid && $0.isSelected }.count
    }

    private var canImport: Bool {
        selectedCount > 0
    }

    private var isBusy: Bool {
        viewModel.isRunningValidation || viewModel.isRunningConnectionTests
    }

    private var hasSearchText: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var importButtonTitle: String {
        guard selectedCount > 0 else {
            return NSLocalizedString("codex.import.sheet.import_selected", value: "导入选中", comment: "Import selected Codex accounts")
        }
        return String(
            format: NSLocalizedString("codex.import.sheet.import_selected_count", value: "导入 %d 个账号", comment: "Import selected Codex accounts with count"),
            selectedCount
        )
    }

    var body: some View {
        NolonUI.CodexImportSheetScaffold(
            data: .init(
                importButtonTitle: importButtonTitle,
                isBusy: isBusy,
                isRunningValidation: viewModel.isRunningValidation,
                canImport: canImport,
                hasAnyCandidates: viewModel.hasAnyCandidates,
                minHeight: Self.minimumSheetHeight(hasAnyCandidates: viewModel.hasAnyCandidates)
            ),
            globalErrorMessage: viewModel.globalErrorMessage,
            onCancel: onCancel,
            onImport: { viewModel.applySelectedImports() },
            dropZone: { dropZone },
            toolbar: { candidateToolbar },
            candidateList: { candidateList }
        )
    }

    private var dropZone: some View {
        NolonUI.CodexImportDropZoneView(
            data: .init(),
            isTargeted: $viewModel.isTargetingDropZone,
            onPickFiles: { viewModel.pickFiles() },
            onPaste: { viewModel.pasteFromClipboard() },
            onDroppedURLs: { urls in
                viewModel.handleDropFiles(urls)
            }
        )
    }

    private var candidateToolbar: some View {
        NolonUI.CodexImportToolbarView(
            data: .init(
                selectedCountText: String(
                    format: NSLocalizedString("codex.accounts.selection.count", value: "已选 %d", comment: "Selected Codex account count"),
                    selectedCount
                ),
                sourceGroupCountText: String(
                    format: NSLocalizedString("codex.import.sheet.source_group_count", value: "%d 个来源组", comment: "Codex import source group count"),
                    viewModel.sections.count
                ),
                isSelectAllDisabled: viewModel.sections.flatMap(\.items).allSatisfy { !$0.validation.isValid },
                isDeselectAllDisabled: viewModel.sections.flatMap(\.items).isEmpty,
                isExportZipDisabled: !canImport || viewModel.isRunningValidation,
                isExportSub2apiDisabled: !canImport || viewModel.isRunningValidation,
                isRetryAllDisabled: viewModel.sections.flatMap(\.items).filter(\.validation.isValid).isEmpty || viewModel.isRunningConnectionTests || viewModel.isRunningValidation
            ),
            searchText: $viewModel.searchText,
            onSelectAll: { viewModel.selectAll() },
            onDeselectAll: { viewModel.deselectAll() },
            onExportZip: { viewModel.exportSelectedAsZIP() },
            onExportSub2api: { viewModel.exportSelectedAsSub2API() },
            onPaste: { viewModel.pasteFromClipboard() },
            onRetryAll: { viewModel.retryAllConnectionTests() }
        )
    }

    private var candidateList: some View {
        NolonUI.CodexImportCandidateListContainerView(
            data: .init(
                hasItems: !viewModel.sections.flatMap(\.items).isEmpty,
                hasSearchText: hasSearchText
            )
        ) {
            ForEach(viewModel.sections) { section in
                sectionView(section)
            }
        }
    }

    private func sectionView(_ section: ProviderUsageEngine.CodexImportCandidateSection) -> some View {
        let isFullySelected = section.selectedItemCount == section.selectableItemCount && section.selectableItemCount > 0
        let data = CodexImportSectionCardData(
            id: section.id,
            title: section.title,
            selectedItemCount: section.selectedItemCount,
            selectableItemCount: section.selectableItemCount,
            selectActionTitle: isFullySelected
                ? NSLocalizedString("codex.import.sheet.group.deselect", value: "取消全选", comment: "Deselect group import candidates")
                : NSLocalizedString("codex.import.sheet.group.select", value: "全选", comment: "Select group import candidates"),
            isSelectActionDisabled: section.selectableItemCount == 0
        )

        return NolonUI.CodexImportSectionCardView(
            data: data,
            onSelectAction: {
                let selectAllInGroup = !isFullySelected
                viewModel.setGroupSelected(selectAllInGroup, sourceGroupID: section.id)
            }
        ) {
            ForEach(section.items) { candidate in
                row(candidate)
            }
        }
    }

    private func row(_ candidate: ProviderUsageEngine.CodexImportCandidate) -> some View {
        let isValid = candidate.validation.isValid
        let rowData = CodexImportCandidateRowData(
            id: candidate.id,
            title: candidate.validation.suggestedName ?? candidate.sourceFileURL.deletingPathExtension().lastPathComponent,
            email: candidate.validation.email,
            sourceFileName: candidate.sourceFileURL.lastPathComponent,
            isValid: isValid,
            isSelected: candidate.isSelected,
            testSummary: candidate.testSummary,
            statusBadge: statusBadgeData(for: candidate),
            canRetry: isValid && candidate.testStatus != .testing,
            canRemove: candidate.testStatus != .testing,
            isRetryDisabled: viewModel.isRunningValidation,
            isSelectionDisabled: !isValid
        )

        return NolonUI.CodexImportCandidateRowView(
            data: rowData,
            onSetSelected: { viewModel.setCandidateSelected($0, id: candidate.id) },
            onRetry: { viewModel.retryConnectionTest(id: candidate.id) },
            onRemove: { viewModel.removeCandidate(id: candidate.id) }
        )
    }

    private func statusBadgeData(for candidate: ProviderUsageEngine.CodexImportCandidate) -> CodexImportStatusBadgeData {
        let label: String
        let tone: CodexImportStatusTone
        switch candidate.testStatus {
        case .idle:
            label = NSLocalizedString("codex.import.sheet.status.idle", value: "待测试", comment: "Idle import test status")
            tone = .neutral
        case .testing:
            label = NSLocalizedString("codex.import.sheet.status.testing", value: "测试中", comment: "Testing import status")
            tone = .info
        case .success:
            label = NSLocalizedString("codex.import.sheet.status.connected", value: "已联通", comment: "Connected import status")
            tone = .success
        case .failure:
            label = candidate.validation.isValid
                ? NSLocalizedString("codex.import.sheet.status.failed", value: "失败", comment: "Failed import status")
                : NSLocalizedString("codex.import.sheet.status.invalid", value: "无效", comment: "Invalid import status")
            tone = .error
        }
        return .init(text: label, tone: tone)
    }

}
