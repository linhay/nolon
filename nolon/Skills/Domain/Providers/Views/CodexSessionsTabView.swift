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
            await viewModel.handleViewAppearance()
        }
        .task(id: "\(provider.id)-\(scenePhase == .active)") {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await viewModel.refreshForForegroundTickIfNeeded()
            }
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
                diagnosticMessage: viewModel.diagnosticMessage,
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
                    onCopySessionID: {
                        copyToPasteboard(detailData.sessionIDCopyValue)
                    },
                    onCopyThreadID: detailData.threadIDCopyValue == nil ? nil : {
                        copyToPasteboard(detailData.threadIDCopyValue ?? "")
                    },
                    onCopyStartedAt: detailData.startedAtCopyValue == nil ? nil : {
                        copyToPasteboard(detailData.startedAtCopyValue ?? "")
                    },
                    onCopyLastActivity: detailData.lastActivityCopyValue == nil ? nil : {
                        copyToPasteboard(detailData.lastActivityCopyValue ?? "")
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
        let timeline = detailTimelineData(for: session)
        return CodexSessionsDetailPanelData(
            title: session.title,
            sessionIDText: session.id,
            sessionIDCopyValue: session.id,
            threadIDText: session.threadID ?? unavailableText,
            threadIDCopyValue: session.threadID,
            providerText: rowData.providerText,
            updatedAtText: rowData.timeText,
            startedAtText: timeline.startedAtText,
            startedAtCopyValue: timeline.startedAtCopyValue,
            lastActivityText: timeline.lastActivityText,
            lastActivityCopyValue: timeline.lastActivityCopyValue,
            projectPath: session.cwd,
            groupTitle: section.title,
            groupSecondaryText: section.titleSecondaryText,
            summary: session.summary,
            usage: detailUsageData(for: rowData.id),
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

    private func detailUsageData(for sessionID: String) -> CodexSessionsDetailUsageData? {
        switch viewModel.usageState(for: sessionID) {
        case .placeholder:
            return .init(
                totalText: NSLocalizedString(
                    "codex.sessions.usage.loading",
                    value: "Loading…",
                    comment: "Usage loading placeholder"
                ),
                inputText: nil,
                outputText: nil,
                cachedText: nil,
                isPlaceholder: true
            )
        case .loaded(let usage):
            return .init(
                totalText: TokenCountFormatters.compact(usage.inputTokens + usage.outputTokens),
                inputText: TokenCountFormatters.compact(usage.inputTokens),
                outputText: TokenCountFormatters.compact(usage.outputTokens),
                cachedText: usage.cachedInputTokens > 0
                    ? TokenCountFormatters.compact(usage.cachedInputTokens)
                    : nil,
                isPlaceholder: false
            )
        case .failed:
            return .init(
                totalText: NSLocalizedString(
                    "codex.sessions.usage.unavailable",
                    value: "Unavailable",
                    comment: "Usage unavailable label"
                ),
                inputText: nil,
                outputText: nil,
                cachedText: nil,
                isPlaceholder: true
            )
        }
    }

    private func detailTimelineData(
        for session: CodexSessionsTabViewModel.SessionRow
    ) -> CodexSessionsDetailTimelineData {
        switch viewModel.timelineState(for: session.id) {
        case .loaded(let timeline):
            return .init(
                startedAtText: detailTimestampText(for: timeline.startedAt) ?? unknownTimeText,
                startedAtCopyValue: detailTimestampText(for: timeline.startedAt),
                lastActivityText: detailTimestampText(for: timeline.lastActivityAt) ?? unknownTimeText,
                lastActivityCopyValue: detailTimestampText(for: timeline.lastActivityAt)
            )
        case .placeholder:
            return .init(
                startedAtText: loadingTimeText,
                startedAtCopyValue: nil,
                lastActivityText: loadingTimeText,
                lastActivityCopyValue: nil
            )
        case .failed:
            return .init(
                startedAtText: unknownTimeText,
                startedAtCopyValue: nil,
                lastActivityText: unknownTimeText,
                lastActivityCopyValue: nil
            )
        }
    }

    private func detailTimestampText(for date: Date?) -> String? {
        guard let date else { return nil }
        return Self.detailTimestampFormatter.string(from: date)
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

    private var loadingTimeText: String {
        NSLocalizedString(
            "codex.sessions.time.loading",
            value: "Loading…",
            comment: "Loading session time"
        )
    }

    private var unknownTimeText: String {
        NSLocalizedString(
            "codex.sessions.time.unknown",
            value: "Unknown",
            comment: "Unknown session time"
        )
    }

    private var unavailableText: String {
        NSLocalizedString(
            "codex.sessions.detail.unavailable",
            value: "Unavailable",
            comment: "Unavailable detail value"
        )
    }

    private static let detailTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

struct CodexSessionsDetailPanelData: Equatable {
    let title: String
    let sessionIDText: String
    let sessionIDCopyValue: String
    let threadIDText: String
    let threadIDCopyValue: String?
    let providerText: String
    let updatedAtText: String
    let startedAtText: String
    let startedAtCopyValue: String?
    let lastActivityText: String
    let lastActivityCopyValue: String?
    let projectPath: String?
    let groupTitle: String?
    let groupSecondaryText: String?
    let summary: String?
    let usage: CodexSessionsDetailUsageData?
    let rolloutPath: String
    let stateRowCount: Int
    let metadataItems: [CodexSessionsMetadataItemData]
    let statusTexts: [String]
    let resumeCommand: String?
    let rowData: CodexSessionsRowData
}

struct CodexSessionsDetailUsageData: Equatable {
    let totalText: String
    let inputText: String?
    let outputText: String?
    let cachedText: String?
    let isPlaceholder: Bool
}

struct CodexSessionsDetailTimelineData: Equatable {
    let startedAtText: String
    let startedAtCopyValue: String?
    let lastActivityText: String
    let lastActivityCopyValue: String?
}

struct CodexSessionsDetailPanelView: View {
    let data: CodexSessionsDetailPanelData
    let onResume: (() -> Void)?
    let onCopySessionID: () -> Void
    let onCopyThreadID: (() -> Void)?
    let onCopyStartedAt: (() -> Void)?
    let onCopyLastActivity: (() -> Void)?
    let onCopyCommand: (() -> Void)?
    let onRevealInFinder: () -> Void
    let onCopyProjectPath: (() -> Void)?
    let onCopyRolloutPath: () -> Void
    @State private var showsDiagnostics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            primaryPanels
            if hasPathRows {
                contextSection
            }
            if hasDiagnostics {
                diagnosticsSection
            }
        }
        .padding(12)
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

    private var headerSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                headerLead
                Spacer(minLength: 8)
                actionCluster
            }
            .frame(minWidth: 700, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                headerLead
                actionCluster
            }
        }
    }

    private var headerLead: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DesignSystem.Colors.primary.opacity(0.12))
                        .frame(width: 30, height: 30)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    titleRow
                    metaSummaryLine
                }
            }

            if let summary = data.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(data.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

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
    }

    private var metaSummaryLine: some View {
        FlowLayout(spacing: 6) {
            summaryTag(text: data.providerText, systemImage: "network")

            if let groupTitle = data.groupTitle, !groupTitle.isEmpty {
                summaryTag(text: groupTitle, systemImage: "square.stack.3d.up")
            }

            if !data.updatedAtText.isEmpty {
                summaryTag(
                    text: String(
                        format: NSLocalizedString(
                            "codex.sessions.detail.updated_at",
                            value: "Updated %@",
                            comment: "Updated at summary"
                        ),
                        data.updatedAtText
                    ),
                    systemImage: "clock"
                )
            }
        }
    }

    private var actionCluster: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                primaryActionButton(
                    title: NSLocalizedString(
                        "codex.sessions.detail.resume",
                        value: "Resume",
                        comment: "Resume codex session"
                    ),
                    systemImage: "play.fill",
                    action: { onResume?() }
                )
                .disabled(onResume == nil)

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

                secondaryActionButton(
                    title: NSLocalizedString(
                        "action.show_in_finder",
                        value: "Show in Finder",
                        comment: "Show in Finder"
                    ),
                    systemImage: "folder",
                    action: onRevealInFinder
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                primaryActionButton(
                    title: NSLocalizedString(
                        "codex.sessions.detail.resume",
                        value: "Resume",
                        comment: "Resume codex session"
                    ),
                    systemImage: "play.fill",
                    action: { onResume?() }
                )
                .disabled(onResume == nil)

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

                    secondaryActionButton(
                        title: NSLocalizedString(
                            "action.show_in_finder",
                            value: "Show in Finder",
                            comment: "Show in Finder"
                        ),
                        systemImage: "folder",
                        action: onRevealInFinder
                    )
                }
            }
        }
    }

    private var primaryPanels: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                usagePanel
                    .frame(width: 220, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    timelinePanel
                    identityPanel
                }
            }
            .frame(minWidth: 760, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                usagePanel
                timelinePanel
                identityPanel
            }
        }
    }

    @ViewBuilder
    private var usagePanel: some View {
        if let usage = data.usage {
            panelCard(
                title: NSLocalizedString(
                    "codex.sessions.table.usage",
                    value: "Usage",
                    comment: "Usage"
                ),
                systemImage: "bolt.horizontal.circle"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(usage.totalText)
                        .font(usage.isPlaceholder ? .title3.weight(.medium) : .title2.weight(.semibold))
                        .foregroundStyle(
                            usage.isPlaceholder
                                ? DesignSystem.Colors.Text.secondary
                                : DesignSystem.Colors.Text.primary
                        )
                        .monospacedDigit()

                    if usage.isPlaceholder {
                        EmptyView()
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            labeledMetricRow(
                                title: NSLocalizedString(
                                    "codex.sessions.detail.input",
                                    value: "Input",
                                    comment: "Input tokens"
                                ),
                                value: usage.inputText
                            )
                            labeledMetricRow(
                                title: NSLocalizedString(
                                    "codex.sessions.detail.output",
                                    value: "Output",
                                    comment: "Output tokens"
                                ),
                                value: usage.outputText
                            )
                            labeledMetricRow(
                                title: NSLocalizedString(
                                    "codex.sessions.detail.cached",
                                    value: "Cached",
                                    comment: "Cached input tokens"
                                ),
                                value: usage.cachedText
                            )
                        }
                    }
                }
            }
        }
    }

    private var timelinePanel: some View {
        panelCard(
            title: NSLocalizedString(
                "codex.sessions.detail.timeline",
                value: "Timeline",
                comment: "Timeline section"
            ),
            systemImage: "clock.arrow.circlepath"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                detailFactRow(
                    title: NSLocalizedString(
                        "codex.sessions.detail.started_at",
                        value: "Started",
                        comment: "Session start time"
                    ),
                    value: data.startedAtText,
                    monospaced: true,
                    onCopy: onCopyStartedAt
                )

                detailFactRow(
                    title: NSLocalizedString(
                        "codex.sessions.detail.last_activity",
                        value: "Last Activity",
                        comment: "Session last activity"
                    ),
                    value: data.lastActivityText,
                    monospaced: true,
                    onCopy: onCopyLastActivity
                )

                detailFactRow(
                    title: NSLocalizedString(
                        "remote.detail.updated_label",
                        value: "Updated",
                        comment: "Updated label"
                    ),
                    value: data.updatedAtText,
                    monospaced: true,
                    onCopy: nil
                )
            }
        }
    }

    private var identityPanel: some View {
        panelCard(
            title: NSLocalizedString(
                "codex.sessions.detail.identity",
                value: "Identity",
                comment: "Identity section"
            ),
            systemImage: "number.square"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                detailFactRow(
                    title: NSLocalizedString(
                        "codex.sessions.detail.session_id",
                        value: "Session ID",
                        comment: "Session identifier"
                    ),
                    value: data.sessionIDText,
                    monospaced: true,
                    onCopy: onCopySessionID
                )

                detailFactRow(
                    title: NSLocalizedString(
                        "codex.sessions.detail.thread_id",
                        value: "Thread ID",
                        comment: "Thread identifier"
                    ),
                    value: data.threadIDText,
                    monospaced: true,
                    onCopy: onCopyThreadID
                )
            }
        }
    }

    private var hasDiagnostics: Bool {
        data.stateRowCount > 0 || !data.metadataItems.isEmpty
    }

    private var hasPathRows: Bool {
        displayedProjectPath != nil || displayedGroupPath != nil || !data.rolloutPath.isEmpty
    }

    private var contextSection: some View {
        panelCard(
            title: NSLocalizedString(
                "codex.sessions.detail.context",
                value: "Context",
                comment: "Context section"
            ),
            systemImage: "folder.badge.questionmark"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if let projectPath = displayedProjectPath {
                    detailPathRow(
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

                if let groupPath = displayedGroupPath {
                    detailPathRow(
                        title: NSLocalizedString(
                            "codex.sessions.detail.group_path",
                            value: "Group Path",
                            comment: "Group path"
                        ),
                        value: groupPath,
                        systemImage: "square.stack.3d.down.right",
                        monospaced: true,
                        onCopy: nil
                    )
                }

                if !data.rolloutPath.isEmpty {
                    detailPathRow(
                        title: NSLocalizedString(
                            "codex.sessions.detail.rollout",
                            value: "Rollout",
                            comment: "Rollout path"
                        ),
                        value: data.rolloutPath,
                        systemImage: "doc.text",
                        monospaced: true,
                        onCopy: onCopyRolloutPath
                    )
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        panelCard(
            title: NSLocalizedString(
                "codex.sessions.detail.diagnostics",
                value: "Diagnostics",
                comment: "Diagnostics section"
            ),
            systemImage: "stethoscope"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showsDiagnostics.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Text(
                            showsDiagnostics
                                ? NSLocalizedString("Collapse", value: "Collapse", comment: "Collapse")
                                : NSLocalizedString("Expand", value: "Expand", comment: "Expand")
                        )
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(diagnosticChips.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(DesignSystem.Colors.Background.surface.opacity(0.8), in: Capsule())

                        Image(systemName: showsDiagnostics ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }
                .buttonStyle(.plain)

                if showsDiagnostics, !diagnosticChips.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(diagnosticChips) { item in
                            diagnosticChip(item)
                        }
                    }
                }
            }
        }
    }

    private var diagnosticChips: [DetailFactItem] {
        var items: [DetailFactItem] = []
        if data.stateRowCount > 0 {
            items.append(
                .init(
                    title: NSLocalizedString(
                        "codex.sessions.detail.db_rows",
                        value: "DB Rows",
                        comment: "Database row count"
                    ),
                    value: "\(data.stateRowCount)",
                    systemImage: "tablecells"
                )
            )
        }
        items.append(
            contentsOf: data.metadataItems.map {
                .init(title: nil, value: $0.text, systemImage: $0.icon)
            }
        )
        return items
    }

    private var displayedProjectPath: String? {
        guard let projectPath = data.projectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !projectPath.isEmpty else {
            return nil
        }
        return projectPath
    }

    private var displayedGroupPath: String? {
        guard let groupPath = data.groupSecondaryText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !groupPath.isEmpty else {
            return nil
        }
        guard groupPath != displayedProjectPath else { return nil }
        return groupPath
    }

    private func diagnosticChip(_ item: DetailFactItem) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: item.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .padding(.top, 1)

            Text(item.value)
                .font(item.title == nil ? .caption : .caption.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.14), lineWidth: 1)
        )
    }

    private func panelCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)

            content()
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

    private func summaryTag(text: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(DesignSystem.Colors.Text.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DesignSystem.Colors.Background.elevated.opacity(0.72), in: Capsule())
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

    @ViewBuilder
    private func labeledMetricRow(title: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                Spacer(minLength: 8)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .monospacedDigit()
            }
        }
    }

    private func detailFactRow(
        title: String,
        value: String,
        monospaced: Bool,
        onCopy: (() -> Void)?
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: 84, alignment: .leading)

            Text(value)
                .font(monospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
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
    }

    private func detailPathRow(
        title: String,
        value: String,
        systemImage: String,
        monospaced: Bool,
        onCopy: (() -> Void)?
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .frame(width: 62, alignment: .leading)

            Text(value)
                .font(monospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                .stroke(DesignSystem.Colors.Component.border.opacity(0.14), lineWidth: 1)
        )
    }

    private struct DetailFactItem: Identifiable {
        let id = UUID()
        let title: String?
        let value: String
        let systemImage: String
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
