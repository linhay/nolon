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
    nonisolated func loadSessionUsage(
        codexHome: URL,
        rolloutPath: String
    ) throws -> CodexSessionTokenTotals?
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
    static let defaultVisibleSessionCountPerSection = 5

    enum SessionGroupingMode: String, CaseIterable, Identifiable, Sendable {
        case project = "project"
        case provider = "provider"

        var id: String { rawValue }
    }

    enum SessionUsageState: Equatable, Sendable {
        case placeholder
        case loaded(CodexSessionTokenTotals)
        case failed
    }

    struct SessionRow: Identifiable, Equatable, Sendable {
        let id: String
        let threadID: String?
        let title: String
        let summary: String?
        let forkedFromID: String?
        let originator: String?
        let source: String?
        let modelProvider: String
        let archived: Bool
        let rolloutPath: String
        let cwd: String?
        let updatedAt: Date?
        let stateRowCount: Int
        let editable: Bool

        init(
            id: String,
            threadID: String?,
            title: String,
            summary: String?,
            forkedFromID: String? = nil,
            originator: String? = nil,
            source: String? = nil,
            modelProvider: String,
            archived: Bool,
            rolloutPath: String,
            cwd: String?,
            updatedAt: Date?,
            stateRowCount: Int,
            editable: Bool
        ) {
            self.id = id
            self.threadID = threadID
            self.title = title
            self.summary = summary
            self.forkedFromID = forkedFromID
            self.originator = originator
            self.source = source
            self.modelProvider = modelProvider
            self.archived = archived
            self.rolloutPath = rolloutPath
            self.cwd = cwd
            self.updatedAt = updatedAt
            self.stateRowCount = stateRowCount
            self.editable = editable
        }

        nonisolated var displayID: String {
            let normalizedThreadID = threadID?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let normalizedThreadID, !normalizedThreadID.isEmpty {
                return normalizedThreadID
            }
            return id
        }
    }

    struct SessionSection: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        let titleSecondaryText: String?
        let rewriteSourceLabel: String
        let rewriteSourceProviderID: String?
        let sessions: [SessionRow]
        let totalSessionCount: Int
        let editableThreadIDs: [String]
        let liveCount: Int
        let archivedCount: Int
        let providerCount: Int
        let isExpanded: Bool

        init(
            id: String,
            title: String,
            titleSecondaryText: String?,
            rewriteSourceLabel: String,
            rewriteSourceProviderID: String?,
            sessions: [SessionRow],
            totalSessionCount: Int,
            editableThreadIDs: [String],
            liveCount: Int,
            archivedCount: Int,
            providerCount: Int,
            isExpanded: Bool = false
        ) {
            self.id = id
            self.title = title
            self.titleSecondaryText = titleSecondaryText
            self.rewriteSourceLabel = rewriteSourceLabel
            self.rewriteSourceProviderID = rewriteSourceProviderID
            self.sessions = sessions
            self.totalSessionCount = totalSessionCount
            self.editableThreadIDs = editableThreadIDs
            self.liveCount = liveCount
            self.archivedCount = archivedCount
            self.providerCount = providerCount
            self.isExpanded = isExpanded
        }

        nonisolated var modelProvider: String { rewriteSourceProviderID ?? title }
        nonisolated var visibleSessionCount: Int { sessions.count }
        nonisolated var hasHiddenSessions: Bool { visibleSessionCount < totalSessionCount }
        nonisolated var remainingSessionCount: Int { max(0, totalSessionCount - visibleSessionCount) }
        nonisolated var hasEditableSessions: Bool { sessions.contains(where: \.editable) }
        nonisolated var hasOverflow: Bool { totalSessionCount > CodexSessionsTabViewModel.defaultVisibleSessionCountPerSection }
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
        let titleSecondaryText: String?
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
    var groupingMode: SessionGroupingMode = .project

    private let service: any CodexSessionsTabServicing
    private let pageSize: Int
    private var allRows: [SessionRow] = []
    private var allSectionStates: [SessionSectionState] = []
    private var expandedSectionIDs: Set<String> = []
    private var usageBySessionID: [String: SessionUsageState] = [:]
    private var usageTasks: [String: Task<Void, Never>] = [:]

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
        0
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
        false
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
            cancelUsageTasks()
            usageBySessionID = [:]
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
        rebuildSectionStates()
    }

    func targetProviders(for currentProviderID: String) -> [String] {
        availableTargetProviderIDs.filter { $0 != currentProviderID }
    }

    func loadNextPage() {
        return
    }

    func toggleSectionExpansion(_ sectionID: String) {
        if expandedSectionIDs.contains(sectionID) {
            expandedSectionIDs.remove(sectionID)
        } else {
            expandedSectionIDs.insert(sectionID)
        }
        rebuildVisibleSections()
    }

    func toggleSectionCollapse(_ sectionID: String) {
        toggleSectionExpansion(sectionID)
    }

    func usageState(for sessionID: String) -> SessionUsageState {
        usageBySessionID[sessionID] ?? .placeholder
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
        let validSessionIDs = Set(presentation.rows.map(\.id))
        pruneUsageState(validSessionIDs: validSessionIDs)
        rebuildSectionStates()
    }

    private func rebuildSectionStates() {
        allSectionStates = Self.makeSectionStates(from: allRows, groupingMode: groupingMode)
        let validSectionIDs = Set(allSectionStates.map(\.id))
        expandedSectionIDs = expandedSectionIDs.intersection(validSectionIDs)
        rebuildVisibleSections()
    }

    private func rebuildVisibleSections() {
        guard !allSectionStates.isEmpty else {
            sections = []
            return
        }

        var visibleSections: [SessionSection] = []
        visibleSections.reserveCapacity(allSectionStates.count)

        for section in allSectionStates {
            let isExpanded = expandedSectionIDs.contains(section.id)
            let visibleCount = isExpanded
                ? section.totalSessionCount
                : min(section.totalSessionCount, Self.defaultVisibleSessionCountPerSection)
            visibleSections.append(
                SessionSection(
                    id: section.id,
                    title: section.title,
                    titleSecondaryText: section.titleSecondaryText,
                    rewriteSourceLabel: section.rewriteSourceLabel,
                    rewriteSourceProviderID: section.rewriteSourceProviderID,
                    sessions: Array(section.sessions.prefix(visibleCount)),
                    totalSessionCount: section.totalSessionCount,
                    editableThreadIDs: section.editableThreadIDs,
                    liveCount: section.liveCount,
                    archivedCount: section.archivedCount,
                    providerCount: section.providerCount,
                    isExpanded: isExpanded
                )
            )
        }

        sections = visibleSections
        primeVisibleSessionUsages()
    }

    nonisolated private static func makePresentation(from snapshot: CodexSessionSnapshot) -> SessionPresentation {
        let rows = snapshot.sessions.map { session in
            SessionRow(
                id: session.id,
                threadID: session.threadID,
                title: compactDisplayText(session.title, maxLength: 120) ?? fallbackTitle(for: session),
                summary: compactDisplayText(session.summary, maxLength: 180),
                forkedFromID: session.forkedFromID,
                originator: session.originator,
                source: session.source,
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
        case .project:
            let grouped = Dictionary(grouping: rows) { row in
                normalizedProjectPath(for: row.cwd) ?? "unknown-project"
            }
            return grouped
                .map { normalizedPath, value in
                    let sortedSessions = value.sorted(by: sortSessionRows(_:_:))
                    let providerIDs = Set(sortedSessions.map(\.modelProvider))
                    let rewriteSourceProviderID = providerIDs.count == 1 ? providerIDs.first : nil
                    let projectName = projectDisplayName(for: normalizedPath)
                    return makeSectionState(
                        id: "project:\(normalizedPath)",
                        title: projectName,
                        titleSecondaryText: normalizedPath == "unknown-project" ? nil : normalizedPath,
                        rewriteSourceLabel: projectName,
                        rewriteSourceProviderID: rewriteSourceProviderID,
                        sessions: sortedSessions,
                        providerCountOverride: providerIDs.count,
                        editableThreadIDsOverride: rewriteSourceProviderID == nil ? [] : nil
                    )
                }
                .sorted(by: sortSections(_:_:))

        case .provider:
            let grouped = Dictionary(grouping: rows, by: \.modelProvider)
            return grouped
                .map { key, value in
                    let sortedSessions = value.sorted(by: sortSessionRows(_:_:))
                    return makeSectionState(
                        id: "provider:\(key)",
                        title: key,
                        titleSecondaryText: nil,
                        rewriteSourceLabel: key,
                        rewriteSourceProviderID: key,
                        sessions: sortedSessions
                    )
                }
                .sorted(by: sortSections(_:_:))
        }
    }

    nonisolated private static func makeSectionState(
        id: String,
        title: String,
        titleSecondaryText: String?,
        rewriteSourceLabel: String,
        rewriteSourceProviderID: String?,
        sessions: [SessionRow],
        providerCountOverride: Int? = nil,
        editableThreadIDsOverride: [String]? = nil
    ) -> SessionSectionState {
        let sortedSessions = sessions.sorted(by: sortSessionRows(_:_:))
        return SessionSectionState(
            id: id,
            title: title,
            titleSecondaryText: titleSecondaryText,
            rewriteSourceLabel: rewriteSourceLabel,
            rewriteSourceProviderID: rewriteSourceProviderID,
            sessions: sortedSessions,
            liveCount: sortedSessions.filter { !$0.archived }.count,
            archivedCount: sortedSessions.filter(\.archived).count,
            editableThreadIDs: editableThreadIDsOverride ?? sortedSessions.compactMap { row in
                guard row.editable else { return nil }
                return row.threadID
            },
            providerCount: providerCountOverride ?? Set(sortedSessions.map(\.modelProvider)).count,
            latestUpdatedAt: sortedSessions.first?.updatedAt
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

    nonisolated private static func sortSessionRows(_ lhs: SessionRow, _ rhs: SessionRow) -> Bool {
        let leftDate = lhs.updatedAt ?? .distantPast
        let rightDate = rhs.updatedAt ?? .distantPast
        if leftDate != rightDate {
            return leftDate > rightDate
        }
        return lhs.displayID.localizedCaseInsensitiveCompare(rhs.displayID) == .orderedAscending
    }

    nonisolated private static func normalizedProjectPath(for cwd: String?) -> String? {
        guard let cwd = cwd?.trimmingCharacters(in: .whitespacesAndNewlines), !cwd.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: cwd).standardizedFileURL.path
    }

    nonisolated private static func projectDisplayName(for normalizedPath: String?) -> String {
        guard let normalizedPath, normalizedPath != "unknown-project" else {
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

    private func primeVisibleSessionUsages() {
        let visibleRows = sections.flatMap(\.sessions)
        guard !visibleRows.isEmpty else { return }
        let codexHome = provider.codexHomeFolder.url

        for row in visibleRows {
            guard usageBySessionID[row.id] == nil, usageTasks[row.id] == nil else { continue }
            usageBySessionID[row.id] = .placeholder
            let service = self.service
            let sessionID = row.id
            let rolloutPath = row.rolloutPath

            usageTasks[sessionID] = Task { [weak self] in
                let nextState: SessionUsageState
                do {
                    let usage = try await Task.detached(priority: .utility) {
                        try service.loadSessionUsage(codexHome: codexHome, rolloutPath: rolloutPath)
                    }.value
                    if let usage {
                        nextState = .loaded(usage)
                    } else {
                        nextState = .failed
                    }
                } catch {
                    nextState = .failed
                }

                await MainActor.run {
                    guard let self else { return }
                    self.usageTasks[sessionID] = nil
                    self.usageBySessionID[sessionID] = nextState
                }
            }
        }
    }

    private func pruneUsageState(validSessionIDs: Set<String>) {
        for (sessionID, task) in usageTasks where !validSessionIDs.contains(sessionID) {
            task.cancel()
            usageTasks.removeValue(forKey: sessionID)
        }
        usageBySessionID = usageBySessionID.filter { validSessionIDs.contains($0.key) }
    }

    private func cancelUsageTasks() {
        for task in usageTasks.values {
            task.cancel()
        }
        usageTasks.removeAll()
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
