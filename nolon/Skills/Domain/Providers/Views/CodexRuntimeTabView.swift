import SwiftUI
import AppKit
import ProviderCatalog
import NolonUI
import NolonUIFoundation

struct CodexRuntimeTabView: View {
    let provider: Provider

    @State private var viewModel: CodexRuntimeTabViewModel

    init(provider: Provider, viewModel: CodexRuntimeTabViewModel? = nil) {
        self.provider = provider
        self._viewModel = State(initialValue: viewModel ?? CodexRuntimeTabViewModel(provider: provider))
    }

    var body: some View {
        NolonUI.ProviderTabScrollScaffold {
            NolonUI.CodexRuntimeTabContentView(
                actionsBarData: actionsBarData,
                onRefresh: {
                    Task { await viewModel.refresh() }
                },
                processesSectionData: processesSectionData,
                isProcessesEmpty: viewModel.processes.isEmpty
            ) {
                ForEach(viewModel.processes) { process in
                    processRow(process)
                }
            }
        }
        .task(id: provider.id) {
            viewModel.stopProcessPolling()
            await viewModel.refresh()
            viewModel.startProcessPolling()
        }
        .onDisappear {
            viewModel.stopProcessPolling()
        }
        .onChange(of: viewModel.selectedPID) { _, _ in
            Task { await viewModel.refreshSelectedProcessLogs() }
        }
        .destructiveConfirmationDialog(
            data: forceStopDialogData,
            isPresented: Binding(
                get: { viewModel.pendingForceStopPID != nil },
                set: { if !$0 { viewModel.pendingForceStopPID = nil } }
            ),
            onConfirm: {
                Task { await viewModel.confirmForceStop() }
            },
            onCancel: {
                viewModel.pendingForceStopPID = nil
            }
        )
        .copyableMessageAlert(
            title: NSLocalizedString("codex.runtime.error.title", value: "Runtime Error", comment: "Runtime error title"),
            message: $viewModel.alertMessage,
            onCopy: { message in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
        )
    }

    private var forceStopDialogData: DestructiveConfirmationDialogData {
        DestructiveConfirmationDialogData(
            title: NSLocalizedString("codex.runtime.force_stop.title", value: "Force Stop", comment: "Force stop confirmation title"),
            message: NSLocalizedString(
                "codex.runtime.force_stop.message",
                value: "This sends SIGKILL directly. Use only when normal stop fails.",
                comment: "Force stop confirmation message"
            ),
            confirmTitle: String(
                format: NSLocalizedString(
                    "codex.runtime.force_stop.action",
                    value: "Force Stop PID %d",
                    comment: "Force stop action"
                ),
                viewModel.pendingForceStopPID ?? 0
            )
        )
    }

    private var actionsBarData: CodexRuntimeActionsBarData {
        CodexRuntimeActionsBarData(
            stopSummary: viewModel.lastStopMessage,
            isBusy: viewModel.isRefreshing || viewModel.isStopping
        )
    }

    private var processesSectionData: CodexRuntimeProcessesSectionData {
        CodexRuntimeProcessesSectionData()
    }

    private func processRow(_ process: CodexRuntimeProcessItem) -> some View {
        let isSelected = viewModel.selectedPID == process.pid

        return NolonUI.CodexRuntimeProcessRowView(
            data: processRowData(process: process, isSelected: isSelected),
            onStop: {
                Task { await viewModel.stop(pid: process.pid, force: false) }
            },
            onForce: {
                viewModel.requestForceStop(pid: process.pid)
            },
            onToggleSelection: {
                viewModel.selectProcess(pid: isSelected ? nil : process.pid)
            }
        ) {
            if isSelected {
                processDiagnosticsSection(process: process)
                inlineLogsSection
            }
        }
    }

    private func processRowData(process: CodexRuntimeProcessItem, isSelected: Bool) -> CodexRuntimeProcessRowData {
        CodexRuntimeProcessRowData(
            id: process.id,
            pidText: String(
                format: NSLocalizedString(
                    "codex.runtime.pid.label",
                    value: "PID %d",
                    comment: "Runtime PID label"
                ),
                process.pid
            ),
            elapsedText: process.elapsed,
            providerHint: process.providerHint,
            commandText: process.command,
            workingDirectory: process.workingDirectory,
            isStopping: viewModel.isStopping,
            isSelected: isSelected
        )
    }

    @ViewBuilder
    private func processDiagnosticsSection(process: CodexRuntimeProcessItem) -> some View {
        let rows = viewModel.processDiagnosticsRows(for: process).map { row in
            CodexRuntimeDiagnosticRowData(
                id: row.key.rawValue,
                label: localizedDiagnosticLabel(for: row.key),
                value: row.value
            )
        }
        NolonUI.CodexRuntimeDiagnosticsCardView(
            rows: rows
        )
    }

    private var inlineLogsSection: some View {
        NolonUI.CodexRuntimeLogsCardView(
            data: logsSectionData,
            onRefresh: {
                Task { await viewModel.refreshSelectedProcessLogs() }
            },
            onCopy: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(viewModel.logsText, forType: .string)
            },
            onClear: {
                viewModel.clearLogs()
            }
        )
    }

    private var logsSectionData: CodexRuntimeLogsSectionData {
        CodexRuntimeLogsSectionData(
            pidText: viewModel.selectedPID.map {
                String(
                    format: NSLocalizedString(
                        "codex.runtime.pid.label",
                        value: "PID %d",
                        comment: "Runtime PID label"
                    ),
                    $0
                )
            },
            isLoading: viewModel.isLoadingLogs,
            logsText: viewModel.logsText,
            errorMessage: viewModel.logsErrorMessage
        )
    }

    private func localizedDiagnosticLabel(for key: CodexRuntimeProcessDiagnosticField.Key) -> String {
        switch key {
        case .provider:
            return NSLocalizedString("codex.runtime.diag.provider", value: "Provider", comment: "Runtime diagnostics provider label")
        case .accounts:
            return NSLocalizedString("codex.runtime.diag.accounts", value: "Accounts", comment: "Runtime diagnostics accounts label")
        case .active:
            return NSLocalizedString("codex.runtime.diag.active", value: "Active", comment: "Runtime diagnostics active account label")
        case .running:
            return NSLocalizedString("codex.runtime.diag.running", value: "Running", comment: "Runtime diagnostics running count label")
        case .binary:
            return NSLocalizedString("codex.runtime.diag.binary", value: "Binary", comment: "Runtime diagnostics binary label")
        case .pathActive:
            return NSLocalizedString("codex.runtime.diag.path_active", value: "Path Active", comment: "Runtime diagnostics path active label")
        case .executable:
            return NSLocalizedString("codex.runtime.diag.executable", value: "Executable", comment: "Runtime diagnostics executable label")
        case .hint:
            return NSLocalizedString("codex.runtime.diag.hint", value: "Hint", comment: "Runtime diagnostics hint label")
        }
    }
}
