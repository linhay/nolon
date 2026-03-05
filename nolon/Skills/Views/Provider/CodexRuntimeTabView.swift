import SwiftUI
import AppKit
import ProviderCatalog

struct CodexRuntimeTabView: View {
    let provider: Provider

    @State private var viewModel: CodexRuntimeTabViewModel

    init(provider: Provider, viewModel: CodexRuntimeTabViewModel? = nil) {
        self.provider = provider
        self._viewModel = State(initialValue: viewModel ?? CodexRuntimeTabViewModel(provider: provider))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                actionsSection
                diagnosticsSection
                processesSection
            }
            .padding(16)
        }
        .task(id: provider.id) {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.selectedPID) { _, _ in
            Task { await viewModel.refreshSelectedProcessLogs() }
        }
        .confirmationDialog(
            NSLocalizedString("codex.runtime.force_stop.title", value: "Force Stop", comment: "Force stop confirmation title"),
            isPresented: Binding(
                get: { viewModel.pendingForceStopPID != nil },
                set: { if !$0 { viewModel.pendingForceStopPID = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pid = viewModel.pendingForceStopPID {
                Button(
                    String(
                        format: NSLocalizedString(
                            "codex.runtime.force_stop.action",
                            value: "Force Stop PID %d",
                            comment: "Force stop action"
                        ),
                        pid
                    ),
                    role: .destructive
                ) {
                    Task { await viewModel.confirmForceStop() }
                }
            }
            Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"), role: .cancel) {
                viewModel.pendingForceStopPID = nil
            }
        } message: {
            Text(
                NSLocalizedString(
                    "codex.runtime.force_stop.message",
                    value: "This sends SIGKILL directly. Use only when normal stop fails.",
                    comment: "Force stop confirmation message"
                )
            )
        }
        .alert(
            NSLocalizedString("codex.runtime.error.title", value: "Runtime Error", comment: "Runtime error title"),
            isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("generic.copy", value: "Copy", comment: "Copy")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(viewModel.alertMessage ?? "", forType: .string)
            }
            Button(NSLocalizedString("generic.ok", value: "OK", comment: "OK"), role: .cancel) {
                viewModel.alertMessage = nil
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var actionsSection: some View {
        HStack(spacing: 10) {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label(
                    NSLocalizedString("codex.runtime.action.refresh", value: "Refresh", comment: "Refresh runtime"),
                    systemImage: "arrow.clockwise"
                )
            }
            .disabled(viewModel.isRefreshing || viewModel.isStopping)

            if let summary = viewModel.lastStopMessage, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            Spacer()
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("codex.runtime.diagnostics.title", value: "Diagnostics", comment: "Runtime diagnostics title"))
                .font(.headline)

            if let diagnostics = viewModel.diagnostics {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        diagnosticLabel(
                            NSLocalizedString(
                                "codex.runtime.diag.provider",
                                value: "Provider",
                                comment: "Runtime diagnostics provider label"
                            )
                        )
                        diagnosticValue(diagnostics.providerID)
                        diagnosticLabel(
                            NSLocalizedString(
                                "codex.runtime.diag.accounts",
                                value: "Accounts",
                                comment: "Runtime diagnostics accounts label"
                            )
                        )
                        diagnosticValue("\(diagnostics.accountCount)")
                    }
                    GridRow {
                        diagnosticLabel(
                            NSLocalizedString(
                                "codex.runtime.diag.active",
                                value: "Active",
                                comment: "Runtime diagnostics active account label"
                            )
                        )
                        diagnosticValue(diagnostics.activeAccountID ?? "-")
                        diagnosticLabel(
                            NSLocalizedString(
                                "codex.runtime.diag.running",
                                value: "Running",
                                comment: "Runtime diagnostics running count label"
                            )
                        )
                        diagnosticValue("\(diagnostics.runtimeCount)")
                    }
                    GridRow {
                        diagnosticLabel(
                            NSLocalizedString(
                                "codex.runtime.diag.binary",
                                value: "Binary",
                                comment: "Runtime diagnostics binary label"
                            )
                        )
                        diagnosticValue(diagnostics.currentVersion ?? "-")
                        diagnosticLabel(
                            NSLocalizedString(
                                "codex.runtime.diag.path_active",
                                value: "Path Active",
                                comment: "Runtime diagnostics path active label"
                            )
                        )
                        diagnosticValue(
                            diagnostics.pathActive
                                ? NSLocalizedString(
                                    "codex.runtime.bool.true",
                                    value: "true",
                                    comment: "Runtime boolean true"
                                )
                                : NSLocalizedString(
                                    "codex.runtime.bool.false",
                                    value: "false",
                                    comment: "Runtime boolean false"
                                )
                        )
                    }
                    GridRow {
                        diagnosticLabel(
                            NSLocalizedString(
                                "codex.runtime.diag.executable",
                                value: "Executable",
                                comment: "Runtime diagnostics executable label"
                            )
                        )
                        diagnosticValue(diagnostics.resolvedExecutable ?? "-")
                        diagnosticLabel(
                            NSLocalizedString(
                                "codex.runtime.diag.hint",
                                value: "Hint",
                                comment: "Runtime diagnostics hint label"
                            )
                        )
                        diagnosticValue(diagnostics.probeHint ?? diagnostics.probeWarning ?? "-")
                    }
                }
            } else {
                Text(NSLocalizedString("codex.runtime.diagnostics.empty", value: "No diagnostics available.", comment: "No diagnostics"))
                    .dsSecondaryText(font: .callout)
            }
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.surface,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
    }

    private var processesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("codex.runtime.processes.title", value: "Runtime Processes", comment: "Runtime process list title"))
                .font(.headline)

            if viewModel.processes.isEmpty {
                Text(NSLocalizedString("codex.runtime.processes.empty", value: "No running Codex processes.", comment: "No runtime process"))
                    .dsSecondaryText(font: .callout)
            } else {
                ForEach(viewModel.processes) { process in
                    processRow(process)
                }
            }
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.surface,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
    }

    private func processRow(_ process: CodexRuntimeProcessItem) -> some View {
        let isSelected = viewModel.selectedPID == process.pid

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(
                    String(
                        format: NSLocalizedString(
                            "codex.runtime.pid.label",
                            value: "PID %d",
                            comment: "Runtime PID label"
                        ),
                        process.pid
                    )
                )
                    .font(.subheadline.monospacedDigit())
                Text(process.elapsed)
                    .font(.caption.monospacedDigit())
                    .dsSecondaryText(font: .caption)
                if let hint = process.providerHint, !hint.isEmpty {
                    Text(hint)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Background.elevated
                        )
                }
                Spacer()
                Button(NSLocalizedString("codex.runtime.process.stop", value: "Stop", comment: "Stop runtime process")) {
                    Task { await viewModel.stop(pid: process.pid, force: false) }
                }
                .disabled(viewModel.isStopping)

                Button(NSLocalizedString("codex.runtime.process.force", value: "Force", comment: "Force stop runtime process")) {
                    viewModel.requestForceStop(pid: process.pid)
                }
                .disabled(viewModel.isStopping)
            }

            Text(process.command)
                .font(.caption.monospaced())
                .lineLimit(2)
                .textSelection(.enabled)
                .dsSecondaryText(font: .caption)

            if let workingDirectory = process.workingDirectory, !workingDirectory.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                    Text(workingDirectory)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .textSelection(.enabled)
                        .dsSecondaryText(font: .caption)
                }
            }

            if isSelected {
                inlineLogsSection
            }
        }
        .padding(10)
        .dsCard(
            background: isSelected ? DesignSystem.Colors.primary.opacity(0.08) : DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: isSelected ? DesignSystem.Colors.primary.opacity(0.45) : DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectProcess(pid: isSelected ? nil : process.pid)
        }
    }

    private var inlineLogsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("codex.runtime.logs.title", value: "PID Logs", comment: "Runtime logs title"))
                    .font(.headline)
                Spacer()
                if let selectedPID = viewModel.selectedPID {
                    Text(
                        String(
                            format: NSLocalizedString(
                                "codex.runtime.pid.label",
                                value: "PID %d",
                                comment: "Runtime PID label"
                            ),
                            selectedPID
                        )
                    )
                        .font(.caption.monospacedDigit())
                        .dsSecondaryText(font: .caption)
                }
            }

            HStack(spacing: 10) {
                Button(NSLocalizedString("codex.runtime.logs.refresh", value: "Refresh Logs", comment: "Refresh logs")) {
                    Task { await viewModel.refreshSelectedProcessLogs() }
                }
                .disabled(viewModel.isLoadingLogs)

                Button(NSLocalizedString("generic.copy", value: "Copy", comment: "Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.logsText, forType: .string)
                }
                .disabled(viewModel.logsText.isEmpty)

                Button(NSLocalizedString("codex.runtime.logs.clear", value: "Clear", comment: "Clear logs")) {
                    viewModel.clearLogs()
                }
                .disabled(viewModel.logsText.isEmpty && viewModel.logsErrorMessage == nil)

                Spacer()

                if viewModel.isLoadingLogs {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let error = viewModel.logsErrorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Status.error)
            }

            ScrollView {
                Text(viewModel.logsText.isEmpty
                     ? NSLocalizedString("codex.runtime.logs.empty", value: "No log output in selected window.", comment: "No logs")
                     : viewModel.logsText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 140)
            .dsCard(
                background: DesignSystem.Colors.Background.elevated,
                cornerRadius: DesignSystem.Metrics.cornerRadiusS,
                borderColor: DesignSystem.Colors.Component.border,
                borderWidth: 1
            )
        }
        .padding(.top, 2)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusS,
            borderColor: DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
    }

    private func diagnosticLabel(_ value: String) -> some View {
        Text(value)
            .font(.caption)
            .dsSecondaryText(font: .caption)
    }

    private func diagnosticValue(_ value: String) -> some View {
        Text(value)
            .font(.callout.monospaced())
            .textSelection(.enabled)
    }
}
