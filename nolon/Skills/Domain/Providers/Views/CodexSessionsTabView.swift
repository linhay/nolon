import AppKit
import SwiftUI
import ProviderCatalog
import CodexProvider
import NolonUI
import NolonUIFoundation
import NolonResourceKit
import STFilePath

struct CodexSessionsTabView: View {
    let provider: Provider

    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: CodexSessionsTabViewModel

    init(provider: Provider, viewModel: CodexSessionsTabViewModel? = nil) {
        self.provider = provider
        self._viewModel = State(
            initialValue: viewModel ?? CodexSessionsTabViewModelStore.shared.viewModel(for: provider)
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        LazyVStack(alignment: .leading, spacing: 16) {
            NolonUI.CodexSessionsOverviewCardView(
                data: overviewData,
                onRefresh: {
                    Task { await viewModel.refresh() }
                },
                onSelectGroupingID: { groupingID in
                    guard let groupingMode = CodexSessionsTabViewModel.SessionGroupingMode(rawValue: groupingID) else {
                        return
                    }
                    viewModel.setGroupingMode(groupingMode)
                },
                onSelectSortingID: { sortingID in
                    guard let sortMode = CodexSessionsTabViewModel.SessionSortMode(rawValue: sortingID) else {
                        return
                    }
                    viewModel.setSortMode(sortMode)
                }
            )

            SearchField(
                config: .init(
                    placeholder: NSLocalizedString(
                        "remote.search.placeholder",
                        value: "Search",
                        comment: "Search placeholder"
                    ),
                    text: $viewModel.searchQuery
                )
            )

            sessionsContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: provider.id) {
            _ = await viewModel.loadIfNeeded()
        }
        .onChange(of: scenePhase) { oldValue, newValue in
            guard oldValue != .active, newValue == .active else { return }
            Task { await viewModel.refreshOnAppActivationIfNeeded() }
        }
        .confirmationAlert(
            data: viewModel.confirmationAlertData,
            isPresented: Binding(
                get: { viewModel.pendingRewrite != nil },
                set: { if !$0 { viewModel.cancelPendingRewrite() } }
            ),
            onConfirm: {
                Task { await viewModel.confirmPendingRewrite() }
            },
            onCancel: {
                viewModel.cancelPendingRewrite()
            }
        )
        .messageAlert(
            title: NSLocalizedString(
                "codex.sessions.error.title",
                value: "Sessions Error",
                comment: "Codex sessions error title"
            ),
            message: $viewModel.alertMessage
        )
    }

    private var skeletonContent: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(0..<3, id: \.self) { sectionIndex in
                NolonUI.CodexSessionsSectionCardView(
                    data: .init(
                        id: "skeleton-section-\(sectionIndex)",
                        title: "project-alpha",
                        usage: .placeholder(text: "Loading…"),
                        titleSecondaryText: "/tmp/project-alpha",
                        subtitle: nil,
                        badges: [
                            .init(id: "live", text: "Live 0"),
                            .init(id: "archived", text: "Archived 0"),
                        ],
                        actions: [],
                        actionMenuTitle: nil,
                        isExpanded: false,
                        expansionTitle: "Expand 3 More",
                        rows: (0..<3).map { rowIndex in
                            .init(
                                id: "skeleton-row-\(sectionIndex)-\(rowIndex)",
                                title: "Session Title Placeholder",
                                idText: "thread-\(rowIndex)",
                                timeText: "2026-04-14 10:00",
                                providerText: "OpenAI (openai)",
                                usage: .placeholder(text: "Loading…"),
                                isArchived: false,
                                isEditable: true,
                                summary: "Loading session preview from Codex rollout logs.",
                                rolloutPath: "sessions/2026/04/11/example.jsonl",
                                showInFinderTitle: nil,
                                copyPathTitle: "Copy Path",
                                stateRowCount: 0,
                                actions: [],
                                readOnlyText: nil
                            )
                        }
                    ),
                    onTapSectionAction: { _ in },
                    onTapRowAction: { _, _ in },
                    onRevealInFinder: { _ in },
                    onToggleCollapse: { _ in }
                )
                .redacted(reason: .placeholder)
            }
        }
    }

    @ViewBuilder
    private var sessionsContent: some View {
        if viewModel.showsInitialSkeleton && viewModel.sections.isEmpty {
            skeletonContent
        } else if viewModel.isLoading && viewModel.sections.isEmpty {
            skeletonContent
        } else if viewModel.sections.isEmpty {
            ContentUnavailableView {
                Label(
                    NSLocalizedString(
                        "codex.sessions.empty.title",
                        value: "No Sessions Found",
                        comment: "Empty sessions title"
                    ),
                    systemImage: "bubble.left.and.bubble.right"
                )
            } description: {
                Text(
                    NSLocalizedString(
                        "codex.sessions.empty.message",
                        value: "No live or archived Codex sessions were found in this provider home.",
                        comment: "Empty sessions description"
                    )
                )
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.sections) { section in
                    sectionCard(for: section)
                }
            }
        }
    }

    private var overviewData: CodexSessionsOverviewData {
        CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: viewModel.groupingMode,
                sortMode: viewModel.sortMode,
                totalSessionCount: viewModel.totalSessionCount,
                groupCount: viewModel.groupCount,
                rewritableGroupCount: viewModel.rewritableGroupCount,
                needsAttentionGroupCount: viewModel.needsAttentionGroupCount,
                statusMessage: viewModel.statusMessage,
                isLoading: viewModel.isLoading,
                hasVisibleSections: !viewModel.sections.isEmpty,
                isPreparingRewrite: viewModel.isPreparingRewrite,
                isApplyingRewrite: viewModel.isApplyingRewrite
            )
        )
    }

    private func revealInFinder(for row: CodexSessionsRowData) {
        let targetURL: URL
        if row.rolloutPath.hasPrefix("/") {
            targetURL = URL(fileURLWithPath: row.rolloutPath)
        } else {
            targetURL = provider.codexHomeFolder.file(row.rolloutPath).url
        }
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
    }

    private func sectionCard(
        for section: CodexSessionsTabViewModel.SessionSection
    ) -> some View {
        let sectionData = CodexSessionsSectionDataBuilder.buildSectionData(
            section,
            groupingMode: viewModel.groupingMode,
            targetProviders: { viewModel.targetProviders(for: $0) },
            usageState: { viewModel.usageState(for: $0) }
        )
        let expandedRowID = section.sessions.contains(where: { $0.id == viewModel.selectedSessionID })
            ? viewModel.selectedSessionID
            : nil

        return NolonUI.CodexSessionsSectionCardView(
            data: sectionData,
            onTapSectionAction: { targetProviderID in
                Task {
                    await viewModel.requestRewrite(for: section, targetProviderID: targetProviderID)
                }
            },
            onTapRowAction: { row, targetProviderID in
                guard let session = section.sessions.first(where: { $0.id == row.id }) else { return }
                Task {
                    await viewModel.requestRewrite(for: session, targetProviderID: targetProviderID)
                }
            },
            onRevealInFinder: { row in
                revealInFinder(for: row)
            },
            onToggleCollapse: { sectionID in
                viewModel.toggleSectionExpansion(sectionID)
            },
            selectedRowID: viewModel.selectedSessionID,
            onSelectRow: { row in
                viewModel.selectSession(row.id)
            },
            expandedRowID: expandedRowID
        ) { row in
            if let detailData = detailPanelData(for: row, in: section) {
                CodexSessionsDetailPanelView(
                    data: detailData,
                    onResume: detailData.resumeCommand == nil ? nil : {
                        resumeSelectedSession(detailData)
                    },
                    onCopyCommand: detailData.resumeCommand == nil ? nil : {
                        copyToPasteboard(detailData.resumeCommand ?? "")
                    },
                    onRevealInFinder: {
                        revealInFinder(for: detailData.rowData)
                    },
                    onCopyProjectPath: detailData.projectPath == nil ? nil : {
                        copyToPasteboard(detailData.projectPath ?? "")
                    },
                    onCopyRolloutPath: {
                        copyToPasteboard(detailData.rowData.rolloutPath)
                    }
                )
            }
        }
    }

    private func detailPanelData(
        for rowData: CodexSessionsRowData,
        in section: CodexSessionsTabViewModel.SessionSection
    ) -> CodexSessionsDetailPanelData? {
        guard viewModel.selectedSessionID == rowData.id else { return nil }
        guard let session = section.sessions.first(where: { $0.id == rowData.id }) else { return nil }
        return CodexSessionsDetailPanelData(
            title: session.title,
            providerText: rowData.providerText,
            timeText: rowData.timeText,
            projectPath: session.cwd,
            groupTitle: section.title,
            groupSecondaryText: section.titleSecondaryText,
            summary: session.summary,
            usageText: usageSummary(for: rowData.usage),
            rolloutPath: rowData.rolloutPath,
            stateRowCount: rowData.stateRowCount,
            metadataItems: rowData.menuMetadataItems,
            statusTexts: detailStatusTexts(for: rowData),
            resumeCommand: CodexSessionsResumeCommandBuilder.commandString(for: session),
            rowData: rowData
        )
    }

    private func detailStatusTexts(for row: CodexSessionsRowData) -> [String] {
        var items: [String] = []
        if !row.isArchived {
            items.append(
                NSLocalizedString(
                    "codex.sessions.badge.live",
                    value: "Live",
                    comment: "Live badge"
                )
            )
        }
        if row.isArchived {
            items.append(
                NSLocalizedString(
                    "codex.sessions.badge.archived",
                    value: "Archived",
                    comment: "Archived badge"
                )
            )
        }
        if !row.isEditable, let readOnlyText = row.readOnlyText, !readOnlyText.isEmpty {
            items.append(readOnlyText)
        }
        return items
    }

    private func usageSummary(for usage: CodexSessionsUsageDisplayData) -> String? {
        switch usage {
        case .placeholder(let text):
            return text
        case .failed(let text):
            return text
        case .value(let primaryText, let secondaryText):
            guard let secondaryText, !secondaryText.isEmpty else { return primaryText }
            return "\(primaryText) · \(secondaryText)"
        }
    }

    private func resumeSelectedSession(_ detailData: CodexSessionsDetailPanelData) {
        guard let command = detailData.resumeCommand else { return }
        let availableApps = orderedTerminalApps()
        guard let targetApp = CodexTerminalApp.resolveTarget(
            explicit: nil,
            preferredBundleID: nil,
            available: availableApps
        ) else {
            viewModel.alertMessage = NSLocalizedString(
                "provider.cli.error.no_terminal",
                value: "No supported terminal app found. Install Terminal or iTerm.",
                comment: "No supported terminal app found"
            )
            return
        }
        do {
            try CodexTerminalLauncher.launchCLI(command: command, in: targetApp)
        } catch {
            viewModel.alertMessage = error.localizedDescription
        }
    }

    private func orderedTerminalApps() -> [CodexTerminalApp] {
        let available = CodexTerminalApp.allCases.filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil
        }
        let preferredOrder: [CodexTerminalApp] = [
            .terminal,
            .iTerm,
            .warpStable,
            .warp,
            .warpPreview,
            .ghostty,
        ]
        var ordered: [CodexTerminalApp] = []
        var seenNames = Set<String>()
        for app in preferredOrder where available.contains(app) {
            let normalizedName = app.displayName.lowercased()
            guard !seenNames.contains(normalizedName) else { continue }
            seenNames.insert(normalizedName)
            ordered.append(app)
        }
        return ordered
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct CodexSessionsDetailPanelData: Equatable {
    let title: String
    let providerText: String
    let timeText: String
    let projectPath: String?
    let groupTitle: String?
    let groupSecondaryText: String?
    let summary: String?
    let usageText: String?
    let rolloutPath: String
    let stateRowCount: Int
    let metadataItems: [CodexSessionsMetadataItemData]
    let statusTexts: [String]
    let resumeCommand: String?
    let rowData: CodexSessionsRowData
}

struct CodexSessionsDetailPanelView: View {
    let data: CodexSessionsDetailPanelData
    let onResume: (() -> Void)?
    let onCopyCommand: (() -> Void)?
    let onRevealInFinder: () -> Void
    let onCopyProjectPath: (() -> Void)?
    let onCopyRolloutPath: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let summary = data.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let resumeCommand = data.resumeCommand, !resumeCommand.isEmpty {
                commandStrip(resumeCommand)
            }

            actionBar
            metadataGrid
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .fill(DesignSystem.Colors.Background.surface.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.18), lineWidth: 1)
        )
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                headerLead
                Spacer(minLength: 12)
                headerActions
            }
            .frame(minWidth: 620, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                headerLead
                headerActions
            }
        }
    }

    private var headerLead: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignSystem.Colors.primary.opacity(0.12))
                            .frame(width: 28, height: 28)

                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }

                    Text(data.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                        .lineLimit(2)

                    statusPills
                }

                contextLine

                if let projectPath = data.projectPath, !projectPath.isEmpty {
                    Button(action: { onCopyProjectPath?() }) {
                        Label(projectPath, systemImage: "folder")
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .help(projectPath)
                }
            }
        }
    }

    @ViewBuilder
    private var statusPills: some View {
        if !data.statusTexts.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(data.statusTexts, id: \.self) { text in
                    Text(text)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(DesignSystem.Colors.Background.elevated.opacity(0.9), in: Capsule())
                }
            }
        }
    }

    private var contextLine: some View {
        HStack(spacing: 8) {
            Label(data.timeText, systemImage: "clock")
            Text("·")
            Text(data.providerText)
            if let groupTitle = data.groupTitle, !groupTitle.isEmpty {
                Text("·")
                Text(groupTitle)
            }
        }
        .font(.caption2)
        .foregroundStyle(DesignSystem.Colors.Text.secondary)
        .lineLimit(1)
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button(action: {
                onResume?()
            }) {
                Label(
                    NSLocalizedString(
                        "codex.sessions.detail.resume",
                        value: "Resume",
                        comment: "Resume codex session"
                    ),
                    systemImage: "play.fill"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(onResume == nil)

            Button(action: onRevealInFinder) {
                Label(
                    NSLocalizedString(
                        "action.show_in_finder",
                        value: "Show in Finder",
                        comment: "Show in Finder"
                    ),
                    systemImage: "folder"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func commandStrip(_ resumeCommand: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            Text(resumeCommand)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onCopyCommand {
                Button(action: onCopyCommand) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .help(
                    NSLocalizedString(
                        "codex.sessions.detail.copy_command",
                        value: "Copy Command",
                        comment: "Copy codex session resume command"
                    )
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.14), lineWidth: 1)
        )
    }

    private var actionBar: some View {
        FlowLayout(spacing: 10) {
            actionChip(
                title: NSLocalizedString(
                    "codex.sessions.detail.copy_rollout",
                    value: "Rollout",
                    comment: "Copy rollout path"
                ),
                systemImage: "doc.on.doc"
            ) {
                onCopyRolloutPath()
            }

            if let onCopyProjectPath {
                actionChip(
                    title: NSLocalizedString(
                        "codex.sessions.detail.copy_project",
                        value: "Project",
                        comment: "Copy project path"
                    ),
                    systemImage: "folder.badge.plus"
                ) {
                    onCopyProjectPath()
                }
            }

            if let onCopyCommand {
                actionChip(
                    title: NSLocalizedString(
                        "codex.sessions.detail.copy_command_short",
                        value: "Command",
                        comment: "Copy resume command"
                    ),
                    systemImage: "terminal"
                ) {
                    onCopyCommand()
                }
            }
        }
    }

    private var metadataGrid: some View {
        let items = detailMetadataItems()
        return LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 170), spacing: 8, alignment: .top),
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                metadataCard(
                    title: item.title,
                    value: item.value,
                    systemImage: item.systemImage,
                    monospaced: item.monospaced
                )
            }
        }
    }

    private func detailMetadataItems() -> [DetailMetadataItem] {
        var items: [DetailMetadataItem] = []

        if let usageText = data.usageText, !usageText.isEmpty {
            items.append(.init(title: NSLocalizedString("codex.sessions.table.usage", value: "Usage", comment: "Usage"), value: usageText, systemImage: "chart.bar", monospaced: false))
        }

        if !data.statusTexts.isEmpty {
            items.append(.init(title: NSLocalizedString("codex.sessions.detail.status", value: "Status", comment: "Session status"), value: data.statusTexts.joined(separator: " · "), systemImage: "circle.hexagongrid.fill", monospaced: false))
        }

        items.append(.init(title: NSLocalizedString("codex.sessions.detail.rollout", value: "Rollout", comment: "Rollout path"), value: data.rolloutPath, systemImage: "doc.text", monospaced: true))

        if data.stateRowCount > 0 {
            items.append(.init(title: NSLocalizedString("codex.sessions.detail.db_rows", value: "DB Rows", comment: "Database row count"), value: "\(data.stateRowCount)", systemImage: "tablecells", monospaced: false))
        }

        if let groupSecondaryText = data.groupSecondaryText, !groupSecondaryText.isEmpty {
            items.append(.init(title: NSLocalizedString("codex.sessions.detail.group_path", value: "Group Path", comment: "Group path"), value: groupSecondaryText, systemImage: "folder", monospaced: true))
        }

        items.append(contentsOf: data.metadataItems.map { item in
            .init(title: metadataTitle(for: item), value: item.text, systemImage: item.icon, monospaced: item.style == .code)
        })

        return items
    }

    private func metadataTitle(for item: CodexSessionsMetadataItemData) -> String {
        switch item.icon {
        case "arrow.triangle.branch":
            return NSLocalizedString(
                "codex.sessions.detail.forked_from",
                value: "Forked From",
                comment: "Session fork source title"
            )
        case "paperplane":
            return NSLocalizedString(
                "codex.sessions.detail.source",
                value: "Source",
                comment: "Session source title"
            )
        case "person.crop.circle":
            return NSLocalizedString(
                "codex.sessions.detail.originator",
                value: "Originator",
                comment: "Session originator title"
            )
        default:
            return NSLocalizedString(
                "codex.sessions.detail.metadata",
                value: "Metadata",
                comment: "Generic session metadata title"
            )
        }
    }

    private func actionChip(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func metadataCard(title: String, value: String, systemImage: String, monospaced: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            Text(value)
                .font(monospaced ? .caption2.monospaced() : .caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.14), lineWidth: 1)
        )
    }

    private struct DetailMetadataItem {
        let title: String
        let value: String
        let systemImage: String
        let monospaced: Bool
    }
}

enum CodexSessionsResumeCommandBuilder {
    nonisolated static func commandString(for session: CodexSessionsTabViewModel.SessionRow) -> String? {
        guard let threadID = sanitized(session.threadID) else { return nil }
        let baseCommand = ["codex", "resume", "--last", threadID]
            .map(shellEscape)
            .joined(separator: " ")

        guard let workingDirectory = sanitized(session.cwd) else {
            return baseCommand
        }
        return "cd \(shellEscape(workingDirectory)) && \(baseCommand)"
    }

    nonisolated private static func sanitized(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    nonisolated private static func shellEscape(_ raw: String) -> String {
        guard raw.rangeOfCharacter(
            from: CharacterSet.whitespacesAndNewlines.union(
                CharacterSet(charactersIn: "\"'\\$&;|<>()[]{}*!?")
            )
        ) != nil else {
            return raw
        }
        return "'" + raw.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
