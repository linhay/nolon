import SwiftUI
import NolonUI
import NolonUIFoundation

struct CodexSessionsDetailPanelView: View {
    let data: CodexSessionsDetailPanelData
    let onCopyThreadID: (() -> Void)?
    let onCopyCommand: (() -> Void)?
    let onRevealInFinder: () -> Void
    let onCopyProjectPath: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeaderSection {
                headerSection
            }
            metadataRail
            footerActionSection
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showsHeaderSection: Bool {
        if let summary = data.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            return true
        }
        return false
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(data.summary ?? "")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionCluster: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                secondaryActionButton(
                    title: NSLocalizedString(
                        "codex.sessions.detail.copy_command_short",
                        value: "Copy Command",
                        comment: "Copy resume command"
                    ),
                    systemImage: "terminal",
                    action: { onCopyCommand?() }
                )
                .disabled(onCopyCommand == nil)

                shareButton

                fileActionButton
            }

            VStack(alignment: .trailing, spacing: 8) {
                secondaryActionButton(
                    title: NSLocalizedString(
                        "codex.sessions.detail.copy_command_short",
                        value: "Copy Command",
                        comment: "Copy resume command"
                    ),
                    systemImage: "terminal",
                    action: { onCopyCommand?() }
                )
                .disabled(onCopyCommand == nil)

                HStack(spacing: 8) {
                    shareButton

                    fileActionButton
                }
            }
        }
    }

    private var footerActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(DesignSystem.Colors.Component.border.opacity(0.12))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 0)
                actionCluster
            }
        }
        .padding(.top, 2)
    }

    private var metadataRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let projectPath = displayedProjectPath {
                metadataRow(
                    title: NSLocalizedString(
                        "codex.sessions.detail.copy_project",
                        value: "Project",
                        comment: "Project path"
                    ),
                    value: projectPath,
                    systemImage: "folder",
                    monospaced: true,
                    onCopy: onCopyProjectPath
                )
            }

            if let projectPath = displayedProjectPath, !projectPath.isEmpty {
                metadataDivider(ifNeeded: true)
            }

            metadataRow(
                title: NSLocalizedString(
                    "codex.sessions.detail.thread_id",
                    value: "Thread ID",
                    comment: "Thread identifier"
                ),
                value: data.threadIDText,
                systemImage: "number.square",
                monospaced: true,
                onCopy: onCopyThreadID
            )

            metadataDivider(ifNeeded: true)

            metadataRow(
                title: NSLocalizedString(
                    "codex.sessions.share.started",
                    value: "Started",
                    comment: "Session share started time label"
                ),
                value: data.startedAtText,
                systemImage: "clock.badge.checkmark",
                monospaced: true,
                onCopy: nil
            )

            if hasDiagnostics {
                metadataDivider(ifNeeded: true)
                diagnosticsRail
            }
        }
        .padding(.vertical, 2)
    }

    private var hasDiagnostics: Bool {
        data.stateRowCount > 0 || !data.metadataItems.isEmpty
    }

    private var diagnosticsRail: some View {
        metadataRow(
            title: NSLocalizedString(
                "codex.sessions.detail.diagnostics",
                value: "Diagnostics",
                comment: "Diagnostics section"
            ),
            value: diagnosticsSummaryText,
            systemImage: "stethoscope",
            monospaced: false,
            onCopy: nil
        )
    }

    private var diagnosticsSummaryText: String {
        var items: [String] = []

        if data.stateRowCount > 0 {
            items.append("DB \(data.stateRowCount)")
        }

        if !data.metadataItems.isEmpty {
            items.append(contentsOf: data.metadataItems.map(\.text))
        }

        let summary = items.joined(separator: " · ")
        if summary.isEmpty {
            return NSLocalizedString(
                "codex.sessions.detail.unavailable",
                value: "Unavailable",
                comment: "Unavailable diagnostics summary"
            )
        }
        return summary
    }

    private func metadataDivider(ifNeeded: Bool) -> some View {
        Group {
            if ifNeeded {
                Rectangle()
                    .fill(DesignSystem.Colors.Component.border.opacity(0.12))
                    .frame(height: 1)
            }
        }
    }

    private var displayedProjectPath: String? {
        guard let projectPath = data.projectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !projectPath.isEmpty else {
            return nil
        }
        return projectPath
    }

    private var fileActionTitle: String {
        NSLocalizedString(
            "action.show_in_finder",
            value: "Show in Finder",
            comment: "Show in Finder"
        )
    }

    private func primaryActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(minHeight: 20)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func secondaryActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .frame(minHeight: 20)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var fileActionButton: some View {
        secondaryActionButton(
            title: fileActionTitle,
            systemImage: "doc.text",
            action: onRevealInFinder
        )
        .help(data.rolloutPath)
    }

    @ViewBuilder
    private var shareButton: some View {
        if let shareData = data.shareData {
            ShareLink(
                item: shareData.item,
                subject: Text(shareData.title)
            ) {
                Label(
                    NSLocalizedString(
                        "codex.sessions.detail.share",
                        value: "Share",
                        comment: "Share codex session"
                    ),
                    systemImage: "square.and.arrow.up"
                )
                .font(.caption2.weight(.semibold))
                .frame(minHeight: 20)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func metadataRow(
        title: String,
        value: String,
        systemImage: String,
        monospaced: Bool,
        onCopy: (() -> Void)?
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(monospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onCopy {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
        }
        .padding(.vertical, 8)
    }

}
