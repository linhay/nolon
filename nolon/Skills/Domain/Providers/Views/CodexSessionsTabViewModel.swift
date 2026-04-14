import Foundation
import Observation
import OSLog
import ProviderCatalog
import CodexProvider
import NolonUIFoundation
import NolonResourceKit
import STFilePath

protocol CodexSessionsTabServicing: Sendable {
    nonisolated func loadSnapshot(codexHome: URL) throws -> CodexSessionSnapshot
    nonisolated func previewRewrite(
        codexHome: URL,
        request: CodexSessionProviderRewriteRequest
    ) throws -> CodexSessionRewritePreview
    nonisolated func rewriteProviders(
        codexHome: URL,
        request: CodexSessionProviderRewriteRequest,
        confirmedPreview: CodexSessionRewritePreview?
    ) throws -> CodexSessionRewriteResult
}

protocol CodexSessionsTabStreamingServicing: Sendable {
    nonisolated func snapshotStream(
        codexHome: URL,
        batchSize: Int
    ) -> AsyncThrowingStream<CodexSessionSnapshot, Error>
}

extension CodexSessionStore: CodexSessionsTabServicing {}
extension CodexSessionStore: CodexSessionsTabStreamingServicing {}

@MainActor
@Observable
final class CodexSessionsTabViewModel {
    static let performanceNotification = Notification.Name("CodexSessionsTabViewModel.performance")
    private static let logger = Logger(subsystem: "com.nolon", category: "CodexSessionsTabViewModel")

    enum SessionGroupingMode: String, CaseIterable, Identifiable, Sendable {
        case provider = "provider"
        case timeProject = "time_project"

        var id: String { rawValue }
    }

    struct SessionRow: Identifiable, Equatable, Sendable {
        let id: String
        let threadID: String?
        let title: String
        let summary: String?
        let modelProvider: String
        let archived: Bool
        let rolloutPath: String
        let cwd: String?
        let updatedAt: Date?
        let stateRowCount: Int
        let editable: Bool
    }

    struct SessionSection: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        let rewriteSourceLabel: String
        let rewriteSourceProviderID: String?
        let sessions: [SessionRow]
        let totalSessionCount: Int
        let editableThreadIDs: [String]
        let liveCount: Int
        let archivedCount: Int
        let providerCount: Int
        let isCollapsed: Bool

        init(
            id: String,
            title: String,
            rewriteSourceLabel: String,
            rewriteSourceProviderID: String?,
            sessions: [SessionRow],
            totalSessionCount: Int,
            editableThreadIDs: [String],
            liveCount: Int,
            archivedCount: Int,
            providerCount: Int,
            isCollapsed: Bool = false
        ) {
            self.id = id
            self.title = title
            self.rewriteSourceLabel = rewriteSourceLabel
            self.rewriteSourceProviderID = rewriteSourceProviderID
            self.sessions = sessions
            self.totalSessionCount = totalSessionCount
            self.editableThreadIDs = editableThreadIDs
            self.liveCount = liveCount
            self.archivedCount = archivedCount
            self.providerCount = providerCount
            self.isCollapsed = isCollapsed
        }

        nonisolated var modelProvider: String { rewriteSourceProviderID ?? title }
        nonisolated var visibleSessionCount: Int { sessions.count }
        nonisolated var hasHiddenSessions: Bool { visibleSessionCount < totalSessionCount }
        nonisolated var remainingSessionCount: Int { max(0, totalSessionCount - visibleSessionCount) }
        nonisolated var hasEditableSessions: Bool { sessions.contains(where: \.editable) }
    }

    struct PendingRewrite: Identifiable, Equatable, Sendable {
        let id = UUID()
        let source: RewriteSourceContext
        let targetProviderID: String
        let request: CodexSessionProviderRewriteRequest
        let preview: CodexSessionRewritePreview
    }

    enum RewriteSourceContext: Equatable, Sendable {
        case section(label: String, providerID: String?)
        case session(title: String, providerID: String)

        var analyticsLabel: String {
            switch self {
            case .section(let label, _):
                return label
            case .session(let title, _):
                return title
            }
        }
    }

    private struct SessionSectionState: Equatable, Sendable {
        let id: String
        let title: String
        let rewriteSourceLabel: String
        let rewriteSourceProviderID: String?
        let sessions: [SessionRow]
        let liveCount: Int
        let archivedCount: Int
        let editableThreadIDs: [String]
        let providerCount: Int
        let latestUpdatedAt: Date?

        nonisolated var totalSessionCount: Int {
            sessions.count
        }

        nonisolated var hasEditableSessions: Bool {
            sessions.contains(where: \.editable)
        }
    }

    private struct SessionPresentation: Equatable, Sendable {
        let availableProviderIDs: [String]
        let rows: [SessionRow]
    }

    let provider: Provider
    var sections: [SessionSection] = []
    var availableTargetProviderIDs: [String] = []
    var isLoading = false
    var isPreparingRewrite = false
    var isApplyingRewrite = false
    var alertMessage: String?
    var statusMessage: String?
    var pendingRewrite: PendingRewrite?
    var showsInitialSkeleton = false
    var groupingMode: SessionGroupingMode = .provider

    private let service: any CodexSessionsTabServicing
    private let pageSize: Int
    private var allRows: [SessionRow] = []
    private var allSectionStates: [SessionSectionState] = []
    private var visibleSessionLimit = 0
    private var collapsedSectionIDs: Set<String> = []

    init(
        provider: Provider,
        service: any CodexSessionsTabServicing = CodexSessionStore(),
        pageSize: Int = 30
    ) {
        self.provider = provider
        self.service = service
        self.pageSize = max(1, pageSize)
    }

    var totalSessionCount: Int {
        allSectionStates.reduce(into: 0) { partialResult, section in
            partialResult += section.totalSessionCount
        }
    }

    var totalLiveCount: Int {
        allSectionStates.reduce(into: 0) { partialResult, section in
            partialResult += section.liveCount
        }
    }

    var totalArchivedCount: Int {
        allSectionStates.reduce(into: 0) { partialResult, section in
            partialResult += section.archivedCount
        }
    }

    var visibleSessionCount: Int {
        sections.reduce(into: 0) { partialResult, section in
            partialResult += section.visibleSessionCount
        }
    }

    var remainingSessionCount: Int {
        max(0, totalSessionCount - visibleSessionCount)
    }

    var groupCount: Int {
        allSectionStates.count
    }

    var rewritableGroupCount: Int {
        allSectionStates.filter {
            sectionPresentationKind(
                hasEditableSessions: $0.hasEditableSessions,
                providerCount: $0.providerCount
            ) == .rewritableGroup
        }.count
    }

    var needsAttentionGroupCount: Int {
        allSectionStates.filter {
            let kind = sectionPresentationKind(
                hasEditableSessions: $0.hasEditableSessions,
                providerCount: $0.providerCount
            )
            return kind != .rewritableGroup
        }.count
    }

    var canLoadMore: Bool {
        visibleSessionCount < totalSessionCount
    }

    var confirmationAlertData: ConfirmationAlertData {
        let pending = pendingRewrite
        let targetProviderID = pending?.targetProviderID ?? ""
        let preview = pending?.preview ?? .init(
            sessionCount: 0,
            liveSessionCount: 0,
            archivedSessionCount: 0,
            stateRowCount: 0
        )
        let targetLabel = Self.inlineProviderLabel(for: targetProviderID)
        let message: String
        switch pending?.source {
        case .some(.section(_, let providerID?)):
            message = String(
                format: NSLocalizedString(
                    "codex.sessions.confirm.message.section",
                    value: "Move sessions from \"%@\" to \"%@\"?\n\nSessions: %d\nLive: %d\nArchived: %d\nDB rows: %d",
                    comment: "Codex sessions rewrite confirmation message for group rewrite"
                ),
                Self.inlineProviderLabel(for: providerID),
                targetLabel,
                preview.sessionCount,
                preview.liveSessionCount,
                preview.archivedSessionCount,
                preview.stateRowCount
            )
        case .some(.session(let title, let providerID)):
            message = String(
                format: NSLocalizedString(
                    "codex.sessions.confirm.message.session",
                    value: "Move \"%@\" from \"%@\" to \"%@\"?\n\nSessions: %d\nLive: %d\nArchived: %d\nDB rows: %d",
                    comment: "Codex sessions rewrite confirmation message for single-session rewrite"
                ),
                title,
                Self.inlineProviderLabel(for: providerID),
                targetLabel,
                preview.sessionCount,
                preview.liveSessionCount,
                preview.archivedSessionCount,
                preview.stateRowCount
            )
        case .some(.section(let label, nil)):
            message = String(
                format: NSLocalizedString(
                    "codex.sessions.confirm.message",
                    value: "Move \"%@\" to \"%@\"?\n\nSessions: %d\nLive: %d\nArchived: %d\nDB rows: %d",
                    comment: "Codex sessions rewrite confirmation message"
                ),
                label,
                targetLabel,
                preview.sessionCount,
                preview.liveSessionCount,
                preview.archivedSessionCount,
                preview.stateRowCount
            )
        case .none:
            message = String(
                format: NSLocalizedString(
                    "codex.sessions.confirm.message",
                    value: "Move \"%@\" to \"%@\"?\n\nSessions: %d\nLive: %d\nArchived: %d\nDB rows: %d",
                    comment: "Codex sessions rewrite confirmation message"
                ),
                "",
                targetLabel,
                preview.sessionCount,
                preview.liveSessionCount,
                preview.archivedSessionCount,
                preview.stateRowCount
            )
        }
        return .init(
            title: NSLocalizedString(
                "codex.sessions.confirm.title",
                value: "Confirm Session Rewrite",
                comment: "Codex sessions rewrite confirmation title"
            ),
            message: message,
            confirmTitle: NSLocalizedString(
                "codex.sessions.confirm.apply",
                value: "Apply",
                comment: "Apply session rewrite"
            ),
            cancelTitle: NSLocalizedString(
                "generic.cancel",
                value: "Cancel",
                comment: "Cancel"
            )
        )
    }

    func load() async {
        let traceID = UUID().uuidString
        let startedAt = CFAbsoluteTimeGetCurrent()
        isLoading = true
        if sections.isEmpty {
            statusMessage = nil
            showsInitialSkeleton = true
        }
        defer { isLoading = false }

        do {
            let codexHome = provider.codexHomeFolder.url
            if let streamingService = service as? any CodexSessionsTabStreamingServicing {
                let stream = streamingService.snapshotStream(
                    codexHome: codexHome,
                    batchSize: min(max(8, pageSize / 3), 16)
                )
                var receivedSnapshot = false
                for try await snapshot in stream {
                    if !receivedSnapshot {
                        Self.emitPerformance(
                            operation: "load_first_snapshot",
                            traceID: traceID,
                            providerID: provider.templateId ?? provider.id,
                            startedAt: startedAt,
                            extra: [
                                "session_count": snapshot.sessions.count,
                                "section_count": sections.count,
                            ]
                        )
                    }
                    receivedSnapshot = true
                    apply(presentation: Self.makePresentation(from: snapshot))
                    showsInitialSkeleton = false
                }
                if !receivedSnapshot {
                    apply(
                        presentation: SessionPresentation(
                            availableProviderIDs: [],
                            rows: []
                        )
                    )
                }
            } else {
                let service = self.service
                let presentation = try await Task.detached(priority: .userInitiated) {
                    let snapshot = try service.loadSnapshot(codexHome: codexHome)
                    return Self.makePresentation(from: snapshot)
                }.value
                apply(presentation: presentation)
                showsInitialSkeleton = false
            }
            Self.emitPerformance(
                operation: "load_complete",
                traceID: traceID,
                providerID: provider.templateId ?? provider.id,
                startedAt: startedAt,
                extra: [
                    "grouping_mode": groupingMode.rawValue,
                    "section_count": sections.count,
                    "session_count": totalSessionCount,
                    "visible_session_count": visibleSessionCount,
                ]
            )
        } catch {
            sections = []
            availableTargetProviderIDs = []
            allRows = []
            allSectionStates = []
            visibleSessionLimit = 0
            showsInitialSkeleton = false
            alertMessage = error.localizedDescription
            Self.emitPerformance(
                operation: "load_failed",
                traceID: traceID,
                providerID: provider.templateId ?? provider.id,
                startedAt: startedAt,
                extra: ["error": error.localizedDescription]
            )
        }
    }

    func refresh() async {
        await load()
    }

    func setGroupingMode(_ newValue: SessionGroupingMode) {
        guard groupingMode != newValue else { return }
        groupingMode = newValue
        rebuildSectionStates(preservedVisibleCount: visibleSessionCount)
    }

    func targetProviders(for currentProviderID: String) -> [String] {
        availableTargetProviderIDs.filter { $0 != currentProviderID }
    }

    func loadNextPage() {
        guard canLoadMore else { return }
        visibleSessionLimit = min(totalSessionCount, visibleSessionLimit + pageSize)
        rebuildVisibleSections()
    }

    func toggleSectionCollapse(_ sectionID: String) {
        collapsedSectionIDs = GenericSelectionStateResolver.resolveMultiSelection(
            current: collapsedSectionIDs,
            tapped: sectionID
        )
        rebuildVisibleSections()
    }

    func requestRewrite(for session: SessionRow, targetProviderID: String) async {
        guard let threadID = session.threadID, session.editable else {
            alertMessage = NSLocalizedString(
                "codex.sessions.error.not_editable",
                value: "This session is missing thread metadata and cannot be rewritten.",
                comment: "Codex session not editable error"
            )
            return
        }
        await prepareRewrite(
            source: .session(title: session.title, providerID: session.modelProvider),
            threadIDs: [threadID],
            targetProviderID: targetProviderID
        )
    }

    func requestRewrite(for section: SessionSection, targetProviderID: String) async {
        await prepareRewrite(
            source: .section(
                label: section.rewriteSourceLabel,
                providerID: section.rewriteSourceProviderID
            ),
            threadIDs: section.editableThreadIDs,
            targetProviderID: targetProviderID
        )
    }

    func cancelPendingRewrite() {
        pendingRewrite = nil
    }

    func confirmPendingRewrite() async {
        guard let pendingRewrite else { return }
        let traceID = UUID().uuidString
        let startedAt = CFAbsoluteTimeGetCurrent()
        isApplyingRewrite = true
        defer { isApplyingRewrite = false }

        do {
            let codexHome = provider.codexHomeFolder.url
            let request = pendingRewrite.request
            let preview = pendingRewrite.preview
            let service = self.service
            let result = try await Task.detached(priority: .userInitiated) {
                try service.rewriteProviders(
                    codexHome: codexHome,
                    request: request,
                    confirmedPreview: preview
                )
            }.value
            self.pendingRewrite = nil
            statusMessage = makeStatusMessage(result: result, targetProviderID: pendingRewrite.targetProviderID)
            if result.preview.sessionCount == 0 || (
                result.liveRolloutFilesUpdated == 0 &&
                result.archivedRolloutFilesUpdated == 0 &&
                result.stateRowsUpdated == 0 &&
                !result.failures.isEmpty
            ) {
                alertMessage = result.failures.joined(separator: "\n")
            }
            Self.emitPerformance(
                operation: "rewrite_apply",
                traceID: traceID,
                providerID: provider.templateId ?? provider.id,
                startedAt: startedAt,
                extra: [
                    "alerted": alertMessage != nil,
                    "failure_count": result.failures.count,
                    "preview_session_count": result.preview.sessionCount,
                    "state_rows_updated": result.stateRowsUpdated,
                    "target_provider_id": pendingRewrite.targetProviderID,
                ]
            )
            await load()
        } catch {
            alertMessage = error.localizedDescription
            Self.emitPerformance(
                operation: "rewrite_apply_failed",
                traceID: traceID,
                providerID: provider.templateId ?? provider.id,
                startedAt: startedAt,
                extra: ["error": error.localizedDescription]
            )
        }
    }

    private func prepareRewrite(
        source: RewriteSourceContext,
        threadIDs: [String],
        targetProviderID: String
    ) async {
        let traceID = UUID().uuidString
        let startedAt = CFAbsoluteTimeGetCurrent()
        guard !threadIDs.isEmpty else {
            alertMessage = NSLocalizedString(
                "codex.sessions.error.empty_selection",
                value: "No editable sessions were selected.",
                comment: "No editable sessions selected"
            )
            return
        }

        isPreparingRewrite = true
        defer { isPreparingRewrite = false }

        do {
            let codexHome = provider.codexHomeFolder.url
            let request = CodexSessionProviderRewriteRequest(threadIDs: threadIDs, targetProviderID: targetProviderID)
            let service = self.service
            let preview = try await Task.detached(priority: .userInitiated) {
                try service.previewRewrite(codexHome: codexHome, request: request)
            }.value
            guard preview.sessionCount > 0 else {
                alertMessage = NSLocalizedString(
                    "codex.sessions.error.no_effect",
                    value: "No matching sessions were found for this rewrite.",
                    comment: "No sessions matched rewrite request"
                )
                return
            }
            pendingRewrite = .init(
                source: source,
                targetProviderID: targetProviderID,
                request: request,
                preview: preview
            )
            Self.emitPerformance(
                operation: "rewrite_preview",
                traceID: traceID,
                providerID: provider.templateId ?? provider.id,
                startedAt: startedAt,
                extra: [
                    "source_label": source.analyticsLabel,
                    "state_row_count": preview.stateRowCount,
                    "target_provider_id": targetProviderID,
                    "thread_count": threadIDs.count,
                ]
            )
        } catch {
            alertMessage = error.localizedDescription
            Self.emitPerformance(
                operation: "rewrite_preview_failed",
                traceID: traceID,
                providerID: provider.templateId ?? provider.id,
                startedAt: startedAt,
                extra: [
                    "error": error.localizedDescription,
                    "target_provider_id": targetProviderID,
                    "thread_count": threadIDs.count,
                ]
            )
        }
    }

    private func apply(presentation: SessionPresentation) {
        availableTargetProviderIDs = presentation.availableProviderIDs
        allRows = presentation.rows
        rebuildSectionStates(preservedVisibleCount: visibleSessionLimit)
    }

    private func rebuildSectionStates(preservedVisibleCount: Int) {
        allSectionStates = Self.makeSectionStates(from: allRows, groupingMode: groupingMode)
        if totalSessionCount == 0 {
            visibleSessionLimit = 0
        } else if preservedVisibleCount > 0 {
            visibleSessionLimit = min(totalSessionCount, max(pageSize, preservedVisibleCount))
        } else {
            visibleSessionLimit = min(totalSessionCount, pageSize)
        }
        rebuildVisibleSections()
    }

    private func rebuildVisibleSections() {
        let sectionCount = allSectionStates.count
        guard sectionCount > 0, visibleSessionLimit > 0 else {
            sections = []
            return
        }

        var visibleCounts = Array(repeating: 0, count: sectionCount)
        var remaining = min(visibleSessionLimit, totalSessionCount)

        let minimumVisibleRowsPerSection = 2
        for _ in 0..<minimumVisibleRowsPerSection where remaining > 0 {
            for index in 0..<sectionCount where remaining > 0 {
                let section = allSectionStates[index]
                guard visibleCounts[index] < section.totalSessionCount else { continue }
                visibleCounts[index] += 1
                remaining -= 1
            }
        }

        if remaining > 0 {
            for index in 0..<sectionCount where remaining > 0 {
                let section = allSectionStates[index]
                let alreadyVisible = visibleCounts[index]
                let additionalCapacity = max(0, section.totalSessionCount - alreadyVisible)
                guard additionalCapacity > 0 else { continue }
                let additionalVisible = min(additionalCapacity, remaining)
                visibleCounts[index] += additionalVisible
                remaining -= additionalVisible
            }
        }

        var visibleSections: [SessionSection] = []
        visibleSections.reserveCapacity(allSectionStates.count)

        for (index, section) in allSectionStates.enumerated() {
            let visibleCount = visibleCounts[index]
            guard visibleCount > 0 else { continue }
            visibleSections.append(
                SessionSection(
                    id: section.id,
                    title: section.title,
                    rewriteSourceLabel: section.rewriteSourceLabel,
                    rewriteSourceProviderID: section.rewriteSourceProviderID,
                    sessions: Array(section.sessions.prefix(visibleCount)),
                    totalSessionCount: section.totalSessionCount,
                    editableThreadIDs: section.editableThreadIDs,
                    liveCount: section.liveCount,
                    archivedCount: section.archivedCount,
                    providerCount: section.providerCount,
                    isCollapsed: collapsedSectionIDs.contains(section.id)
                )
            )
        }

        sections = visibleSections
    }

    nonisolated private static func makePresentation(from snapshot: CodexSessionSnapshot) -> SessionPresentation {
        let rows = snapshot.sessions.map { session in
            SessionRow(
                id: session.id,
                threadID: session.threadID,
                title: compactDisplayText(session.title, maxLength: 120) ?? fallbackTitle(for: session),
                summary: compactDisplayText(session.summary, maxLength: 180),
                modelProvider: session.modelProvider,
                archived: session.archived,
                rolloutPath: session.rolloutPath,
                cwd: session.cwd,
                updatedAt: session.updatedAt,
                stateRowCount: session.stateRowCount,
                editable: session.editable
            )
        }

        return SessionPresentation(
            availableProviderIDs: snapshot.availableProviderIDs,
            rows: rows
        )
    }

    nonisolated private static func makeSectionStates(
        from rows: [SessionRow],
        groupingMode: SessionGroupingMode
    ) -> [SessionSectionState] {
        switch groupingMode {
        case .provider:
            let grouped = Dictionary(grouping: rows, by: \.modelProvider)
            return grouped
                .map { key, value in
                    makeSectionState(
                        id: "provider:\(key)",
                        title: key,
                        rewriteSourceLabel: key,
                        rewriteSourceProviderID: key,
                        sessions: value
                    )
                }
                .sorted(by: sortSections(_:_:))

        case .timeProject:
            let grouped = Dictionary(grouping: rows) { row in
                let dayKey = sessionDayKey(for: row.updatedAt) ?? "unknown-day"
                let projectPath = normalizedProjectPath(for: row.cwd) ?? "unknown-project"
                return "\(dayKey)|\(projectPath)"
            }
            return grouped
                .map { _, value in
                    let dayLabel = sessionDayKey(for: value.first?.updatedAt)
                        ?? NSLocalizedString(
                            "codex.sessions.group.unknown_day",
                            value: "Unknown Day",
                            comment: "Unknown session day label"
                        )
                    let projectName = projectDisplayName(for: value.first?.cwd)
                    let providerIDs = Set(value.map(\.modelProvider))
                    let rewriteSourceProviderID = providerIDs.count == 1 ? providerIDs.first : nil
                    return makeSectionState(
                        id: "time-project:\(dayLabel)|\(normalizedProjectPath(for: value.first?.cwd) ?? "unknown-project")",
                        title: "\(dayLabel) · \(projectName)",
                        rewriteSourceLabel: "\(dayLabel) · \(projectName)",
                        rewriteSourceProviderID: rewriteSourceProviderID,
                        sessions: value,
                        providerCountOverride: providerIDs.count,
                        editableThreadIDsOverride: rewriteSourceProviderID == nil ? [] : nil
                    )
                }
                .sorted(by: sortSections(_:_:))
        }
    }

    nonisolated private static func makeSectionState(
        id: String,
        title: String,
        rewriteSourceLabel: String,
        rewriteSourceProviderID: String?,
        sessions: [SessionRow],
        providerCountOverride: Int? = nil,
        editableThreadIDsOverride: [String]? = nil
    ) -> SessionSectionState {
        SessionSectionState(
            id: id,
            title: title,
            rewriteSourceLabel: rewriteSourceLabel,
            rewriteSourceProviderID: rewriteSourceProviderID,
            sessions: sessions,
            liveCount: sessions.filter { !$0.archived }.count,
            archivedCount: sessions.filter(\.archived).count,
            editableThreadIDs: editableThreadIDsOverride ?? sessions.compactMap { row in
                guard row.editable else { return nil }
                return row.threadID
            },
            providerCount: providerCountOverride ?? Set(sessions.map(\.modelProvider)).count,
            latestUpdatedAt: sessions.first?.updatedAt
        )
    }

    nonisolated private static func sortSections(_ lhs: SessionSectionState, _ rhs: SessionSectionState) -> Bool {
        let leftDate = lhs.latestUpdatedAt ?? .distantPast
        let rightDate = rhs.latestUpdatedAt ?? .distantPast
        if leftDate != rightDate {
            return leftDate > rightDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    nonisolated private static func fallbackTitle(for session: CodexSessionRecord) -> String {
        if let lastPathComponent = session.rolloutPath.split(separator: "/").last, !lastPathComponent.isEmpty {
            return String(lastPathComponent)
        }
        return NSLocalizedString(
            "codex.sessions.untitled",
            value: "Untitled Session",
            comment: "Fallback codex session title"
        )
    }

    nonisolated private static func compactDisplayText(_ raw: String?, maxLength: Int) -> String? {
        guard let raw else { return nil }
        let collapsed = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        guard collapsed.count > maxLength else { return collapsed }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
        return String(collapsed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    nonisolated private static func sessionDayKey(for date: Date?) -> String? {
        guard let date else { return nil }
        return dayFormatter.string(from: date)
    }

    nonisolated private static func normalizedProjectPath(for cwd: String?) -> String? {
        guard let cwd = cwd?.trimmingCharacters(in: .whitespacesAndNewlines), !cwd.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: cwd).standardizedFileURL.path
    }

    nonisolated private static func projectDisplayName(for cwd: String?) -> String {
        guard let normalizedPath = normalizedProjectPath(for: cwd) else {
            return NSLocalizedString(
                "codex.sessions.group.unknown_project",
                value: "Unknown Project",
                comment: "Unknown session project label"
            )
        }
        let projectName = URL(fileURLWithPath: normalizedPath).lastPathComponent
        if projectName.isEmpty {
            return normalizedPath
        }
        return projectName
    }

    private func makeStatusMessage(
        result: CodexSessionRewriteResult,
        targetProviderID: String
    ) -> String {
        let format = NSLocalizedString(
            "codex.sessions.status.success",
            value: "Moved %d sessions to \"%@\". Updated %d live files, %d archived files, and %d DB rows.",
            comment: "Codex sessions rewrite success message"
        )
        return String(
            format: format,
            result.preview.sessionCount,
            Self.inlineProviderLabel(for: targetProviderID),
            result.liveRolloutFilesUpdated,
            result.archivedRolloutFilesUpdated,
            result.stateRowsUpdated
        ) + makeStatusWarningSuffix(for: result.failures)
    }

    private func makeStatusWarningSuffix(for failures: [String]) -> String {
        guard !failures.isEmpty else { return "" }
        return "\n" + failures.joined(separator: "\n")
    }

    nonisolated private static func emitPerformance(
        operation: String,
        traceID: String,
        providerID: String,
        startedAt: CFAbsoluteTime,
        extra: [String: Any]
    ) {
        let elapsedMs = Int(((CFAbsoluteTimeGetCurrent() - startedAt) * 1_000).rounded())
        var payload = extra
        payload["elapsed_ms"] = elapsedMs
        payload["operation"] = operation
        payload["provider_id"] = providerID
        payload["trace_id"] = traceID

        let details = payload.keys.sorted().compactMap { key -> String? in
            guard let value = payload[key] else { return nil }
            return "\(key)=\(value)"
        }.joined(separator: " ")
        logger.info("performance \(details, privacy: .public)")
        NotificationCenter.default.post(
            name: performanceNotification,
            object: nil,
            userInfo: payload
        )
    }

    nonisolated private static func inlineProviderLabel(for providerID: String) -> String {
        CodexSessionsSectionDataBuilder.providerPresentation(for: providerID).inlineText
    }

    private func sectionPresentationKind(
        hasEditableSessions: Bool,
        providerCount: Int
    ) -> CodexSessionsSectionPresentationKind {
        if !hasEditableSessions {
            return .readOnly
        }
        if providerCount > 1 {
            return .singleSessionOnly
        }
        return .rewritableGroup
    }

    nonisolated private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
