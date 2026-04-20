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
            .frame(maxWidth: .infinity, alignment: .leading)

            sessionsContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.disabled)
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
                totalUsage: viewModel.totalUsage,
                groupUsage: viewModel.groupUsage,
                rewritableGroupUsage: viewModel.rewritableGroupUsage,
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
            usageState: { viewModel.usageState(for: $0) },
            shareData: viewModel.sectionShareData(for: section.id)
        )
        let sectionThreadIDs = viewModel.threadIDsForSection(section.id)
        let sectionFolderPath = viewModel.sectionFolderPath(for: section.id)
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
            onCopySectionThreadIDs: sectionThreadIDs.isEmpty
                ? nil
                : {
                    copyToPasteboard(sectionThreadIDs.joined(separator: "\n"))
                },
            onRevealSectionFolder: sectionFolderPath.map { path in
                {
                    revealSectionFolder(path: path)
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
            onToggleRowExpansion: { row in
                if viewModel.selectedSessionID == row.id {
                    viewModel.deselectSession()
                } else {
                    viewModel.selectSession(row.id)
                }
            },
            expandedRowID: expandedRowID
        ) { row in
            if let detailData = detailPanelData(for: row, in: section) {
                CodexSessionsDetailPanelView(
                    data: detailData,
                    onCopyThreadID: detailData.threadIDCopyValue == nil ? nil : {
                        copyToPasteboard(detailData.threadIDCopyValue ?? "")
                    },
                    onCopyCommand: detailData.resumeCommand == nil ? nil : {
                        copyToPasteboard(detailData.resumeCommand ?? "")
                    },
                    onRevealInFinder: {
                        revealInFinder(for: detailData.rowData)
                    },
                    onCopyProjectPath: detailData.projectPath == nil ? nil : {
                        copyToPasteboard(detailData.projectPath ?? "")
                    }
                )
            }
        }
    }

    private func revealSectionFolder(path: String) {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
    }

    private func detailPanelData(
        for rowData: CodexSessionsRowData,
        in section: CodexSessionsTabViewModel.SessionSection
    ) -> CodexSessionsDetailPanelData? {
        guard viewModel.selectedSessionID == rowData.id else { return nil }
        guard let session = section.sessions.first(where: { $0.id == rowData.id }) else { return nil }
        let timeline = detailTimelineData(for: session)
        let provisionalData = CodexSessionsDetailPanelData(
            threadIDText: session.threadID ?? unavailableText,
            threadIDCopyValue: session.threadID,
            providerText: rowData.providerText,
            startedAtText: timeline.startedAtText,
            lastActivityText: timeline.lastActivityText,
            projectPath: session.cwd,
            groupTitle: section.title,
            summary: session.summary,
            usage: detailUsageData(for: rowData.id),
            rolloutPath: rowData.rolloutPath,
            stateRowCount: rowData.stateRowCount,
            metadataItems: rowData.menuMetadataItems,
            statusTexts: detailStatusTexts(for: rowData),
            resumeCommand: CodexSessionsResumeCommandBuilder.commandString(for: session),
            shareData: nil,
            rowData: rowData
        )
        return CodexSessionsDetailPanelData(
            threadIDText: provisionalData.threadIDText,
            threadIDCopyValue: provisionalData.threadIDCopyValue,
            providerText: provisionalData.providerText,
            startedAtText: provisionalData.startedAtText,
            lastActivityText: provisionalData.lastActivityText,
            projectPath: provisionalData.projectPath,
            groupTitle: provisionalData.groupTitle,
            summary: provisionalData.summary,
            usage: provisionalData.usage,
            rolloutPath: provisionalData.rolloutPath,
            stateRowCount: provisionalData.stateRowCount,
            metadataItems: provisionalData.metadataItems,
            statusTexts: provisionalData.statusTexts,
            resumeCommand: provisionalData.resumeCommand,
            shareData: CodexSessionsShareContentBuilder.makeSessionShareData(from: provisionalData),
            rowData: provisionalData.rowData
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
                lastActivityText: detailTimestampText(for: timeline.lastActivityAt) ?? unknownTimeText
            )
        case .placeholder:
            return .init(
                startedAtText: loadingTimeText,
                lastActivityText: loadingTimeText
            )
        case .failed:
            return .init(
                startedAtText: unknownTimeText,
                lastActivityText: unknownTimeText
            )
        }
    }

    private func detailTimestampText(for date: Date?) -> String? {
        guard let date else { return nil }
        return Self.detailTimestampFormatter.string(from: date)
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

enum CodexSessionsResumeCommandBuilder {
    nonisolated static func commandString(for session: CodexSessionsTabViewModel.SessionRow) -> String? {
        guard let threadID = sanitized(session.threadID) else { return nil }
        return ["codex", "resume", "--last", threadID]
            .map(shellEscape)
            .joined(separator: " ")
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
