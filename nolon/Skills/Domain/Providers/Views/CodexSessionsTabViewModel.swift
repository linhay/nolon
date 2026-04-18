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
    nonisolated func loadSessionTimeline(
        codexHome: URL,
        rolloutPath: String
    ) throws -> CodexSessionTimeline?
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
    ) -> AsyncThrowingStream<CodexSessionSnapshotDelta, Error>
}

protocol CodexSessionsTabPreloadingServicing: Sendable {
    nonisolated func loadProjectSkeletonSnapshot(
        codexHome: URL
    ) throws -> CodexSessionProjectSkeletonSnapshot
}

extension CodexSessionStore: CodexSessionsTabServicing {}
extension CodexSessionStore: CodexSessionsTabStreamingServicing {}
extension CodexSessionStore: CodexSessionsTabPreloadingServicing {}

@MainActor
final class CodexSessionsTabViewModelStore {
    static let shared = CodexSessionsTabViewModelStore()

    private struct CachedEntry {
        let viewModel: CodexSessionsTabViewModel
    }

    private let viewModelFactory: @MainActor (Provider) -> CodexSessionsTabViewModel
    private var cached: [Provider.ID: CachedEntry] = [:]

    init(
        viewModelFactory: @escaping @MainActor (Provider) -> CodexSessionsTabViewModel = {
            CodexSessionsTabViewModel(provider: $0)
        }
    ) {
        self.viewModelFactory = viewModelFactory
    }

    func viewModel(for provider: Provider) -> CodexSessionsTabViewModel {
        if let existing = cached[provider.id] {
            return existing.viewModel
        }
        let created = viewModelFactory(provider)
        cached[provider.id] = .init(viewModel: created)
        return created
    }

    func clear() {
        cached.removeAll()
    }
}

@MainActor
@Observable
final class CodexSessionsTabViewModel {
    nonisolated static let performanceNotification = Notification.Name("CodexSessionsTabViewModel.performance")
    nonisolated private static let logger = Logger(subsystem: "com.nolon", category: "CodexSessionsTabViewModel")
    nonisolated static let defaultVisibleSessionCountPerSection = 5
    nonisolated private static let usageSortingParallelism = 6
    nonisolated private static let slowStoreOperationThresholdMS = 1_500

    enum SessionGroupingMode: String, CaseIterable, Identifiable, Sendable {
        case project = "project"
        case provider = "provider"

        var id: String { rawValue }
    }

    enum SessionSortMode: String, CaseIterable, Identifiable, Sendable {
        case recent = "recent"
        case usage = "usage"

        var id: String { rawValue }
    }

    enum SessionUsageState: Equatable, Sendable {
        case placeholder
        case loaded(CodexSessionTokenTotals)
        case failed
    }

    enum SessionTimelineState: Equatable, Sendable {
        case placeholder
        case loaded(CodexSessionTimeline)
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

        nonisolated init(
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
        let usageSessionIDs: [String]
        let sessions: [SessionRow]
        let totalSessionCount: Int
        let editableThreadIDs: [String]
        let liveCount: Int
        let archivedCount: Int
        let providerCount: Int
        let isExpanded: Bool
        let isPlaceholder: Bool

        init(
            id: String,
            title: String,
            titleSecondaryText: String?,
            rewriteSourceLabel: String,
            rewriteSourceProviderID: String?,
            usageSessionIDs: [String],
            sessions: [SessionRow],
            totalSessionCount: Int,
            editableThreadIDs: [String],
            liveCount: Int,
            archivedCount: Int,
            providerCount: Int,
            isExpanded: Bool = false,
            isPlaceholder: Bool = false
        ) {
            self.id = id
            self.title = title
            self.titleSecondaryText = titleSecondaryText
            self.rewriteSourceLabel = rewriteSourceLabel
            self.rewriteSourceProviderID = rewriteSourceProviderID
            self.usageSessionIDs = usageSessionIDs
            self.sessions = sessions
            self.totalSessionCount = totalSessionCount
            self.editableThreadIDs = editableThreadIDs
            self.liveCount = liveCount
            self.archivedCount = archivedCount
            self.providerCount = providerCount
            self.isExpanded = isExpanded
            self.isPlaceholder = isPlaceholder
        }

        nonisolated var modelProvider: String { rewriteSourceProviderID ?? title }
        nonisolated var visibleSessionCount: Int { sessions.count }
        nonisolated var hasHiddenSessions: Bool { visibleSessionCount < totalSessionCount }
        nonisolated var remainingSessionCount: Int { max(0, totalSessionCount - visibleSessionCount) }
        nonisolated var hasEditableSessions: Bool { sessions.contains(where: \.editable) }
        nonisolated var hasOverflow: Bool {
            !isPlaceholder && totalSessionCount > CodexSessionsTabViewModel.defaultVisibleSessionCountPerSection
        }
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
        let totalSessionCount: Int
        let liveCount: Int
        let archivedCount: Int
        let editableThreadIDs: [String]
        let providerCount: Int
        let latestUpdatedAt: Date?
        let usageTotalTokens: Int
        let usageAvailabilityRank: Int
        let isPlaceholder: Bool

        nonisolated var hasEditableSessions: Bool {
            sessions.contains(where: \.editable)
        }
    }

    private struct SessionPresentation: Equatable, Sendable {
        let availableProviderIDs: [String]
        let rows: [SessionRow]
    }

    private struct SessionDeltaPresentation: Equatable, Sendable {
        let availableProviderIDs: [String]
        let rows: [SessionRow]
        let removedSessionIDs: [String]
        let isComplete: Bool
    }

    private enum ReloadMode {
        case initial
        case refresh
    }

    let provider: Provider
    var sections: [SessionSection] = []
    var availableTargetProviderIDs: [String] = []
    var isLoading = false
    var isPreparingRewrite = false
    var isApplyingRewrite = false
    var alertMessage: String?
    var statusMessage: String?
    var diagnosticMessage: String? {
        diagnosticWarningMessage ?? diagnosticPerformanceMessage
    }
    var pendingRewrite: PendingRewrite?
    var showsInitialSkeleton = false
    var groupingMode: SessionGroupingMode = .project
    var sortMode: SessionSortMode = .recent
    var selectedSessionID: String?
    var searchQuery: String = "" {
        didSet {
            guard Self.normalizedSearchQuery(searchQuery) != Self.normalizedSearchQuery(oldValue) else {
                return
            }
            scheduleSearchRebuild()
        }
    }

    private let service: any CodexSessionsTabServicing
    private let preferencesStore: CodexSessionsPreferencesStore
    private let pageSize: Int
    private let autoRefreshInterval: TimeInterval
    private let dateProvider: @Sendable () -> Date
    private let searchDebounceNanoseconds: UInt64
    private var didStartInitialLoad = false
    private var lastSuccessfulReloadAt: Date?
    private var rowsByID: [String: SessionRow] = [:]
    private var allSectionStates: [SessionSectionState] = []
    private var projectSkeletons: [CodexSessionProjectSkeleton] = []
    private var projectRowIDsBySectionID: [String: [String]] = [:]
    private var providerRowIDsBySectionID: [String: [String]] = [:]
    private var expandedSectionIDs: Set<String> = []
    private var usageBySessionID: [String: SessionUsageState] = [:]
    private var usageTasks: [String: Task<Void, Never>] = [:]
    private var queuedUsageSessionIDs: [String] = []
    private var queuedUsageSessionIDSet: Set<String> = []
    private var timelineBySessionID: [String: SessionTimelineState] = [:]
    private var timelineTasks: [String: Task<Void, Never>] = [:]
    private var timelineRequestIDsBySessionID: [String: UUID] = [:]
    private var appliedSearchQuery: String = ""
    private var searchDebounceTask: Task<Void, Never>?
    private var usageSortRebuildTask: Task<Void, Never>?
    private var isProjectOrderLocked = false
    private var didInstallDiagnosticObservers = false
    private var diagnosticWarningMessage: String?
    private var diagnosticPerformanceMessage: String?

    private var allRows: [SessionRow] {
        Array(rowsByID.values)
    }

    init(
        provider: Provider,
        service: any CodexSessionsTabServicing = CodexSessionStore(),
        pageSize: Int = 30,
        preferencesStore: CodexSessionsPreferencesStore? = nil,
        autoRefreshInterval: TimeInterval = 60,
        dateProvider: @escaping @Sendable () -> Date = Date.init,
        searchDebounceNanoseconds: UInt64 = 250_000_000
    ) {
        self.provider = provider
        self.service = service
        self.pageSize = max(1, pageSize)
        let resolvedPreferencesStore = preferencesStore ?? CodexSessionsPreferencesStore(providerID: provider.id)
        self.preferencesStore = resolvedPreferencesStore
        self.groupingMode = resolvedPreferencesStore.groupingMode
        self.sortMode = resolvedPreferencesStore.sortMode
        self.autoRefreshInterval = max(1, autoRefreshInterval)
        self.dateProvider = dateProvider
        self.searchDebounceNanoseconds = searchDebounceNanoseconds
    }

    nonisolated deinit {}

    @discardableResult
    func loadIfNeeded() async -> Bool {
        ensureDiagnosticObserversInstalled()
        guard !didStartInitialLoad else { return false }
        didStartInitialLoad = true
        await load()
        return true
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

    var selectedSession: SessionRow? {
        guard let selectedSessionID else { return nil }
        return rowsByID[selectedSessionID]
    }

    var selectedSection: SessionSection? {
        guard let selectedSessionID else { return nil }
        if let visibleSection = sections.first(where: { section in
            section.sessions.contains(where: { $0.id == selectedSessionID })
        }) {
            return visibleSection
        }
        guard let sectionState = allSectionStates.first(where: { section in
            section.sessions.contains(where: { $0.id == selectedSessionID })
        }) else {
            return nil
        }
        let isExpanded = expandedSectionIDs.contains(sectionState.id)
        return SessionSection(
            id: sectionState.id,
            title: sectionState.title,
            titleSecondaryText: sectionState.titleSecondaryText,
            rewriteSourceLabel: sectionState.rewriteSourceLabel,
            rewriteSourceProviderID: sectionState.rewriteSourceProviderID,
            usageSessionIDs: sectionState.sessions.map(\.id),
            sessions: visibleSessions(for: sectionState, isExpanded: isExpanded),
            totalSessionCount: sectionState.totalSessionCount,
            editableThreadIDs: sectionState.editableThreadIDs,
            liveCount: sectionState.liveCount,
            archivedCount: sectionState.archivedCount,
            providerCount: sectionState.providerCount,
            isExpanded: isExpanded,
            isPlaceholder: sectionState.isPlaceholder
        )
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
        ensureDiagnosticObserversInstalled()
        didStartInitialLoad = true
        await reload(mode: .initial)
    }

    func handleViewAppearance() async {
        let didLoad = await loadIfNeeded()
        guard !didLoad else { return }
        await refreshIfStale()
    }

    func refresh() async {
        ensureDiagnosticObserversInstalled()
        await reload(mode: .refresh)
    }

    func refreshForForegroundTickIfNeeded() async {
        await refreshIfStale()
    }

    func refreshOnAppActivationIfNeeded() async {
        guard didStartInitialLoad else { return }
        guard !isLoading, !isPreparingRewrite, !isApplyingRewrite else { return }
        await refresh()
    }

    private func refreshIfStale() async {
        guard didStartInitialLoad else { return }
        guard !isLoading, !isPreparingRewrite, !isApplyingRewrite else { return }
        guard shouldRefreshForStaleness() else { return }
        await refresh()
    }

    private func shouldRefreshForStaleness() -> Bool {
        guard let lastSuccessfulReloadAt else { return true }
        return dateProvider().timeIntervalSince(lastSuccessfulReloadAt) >= autoRefreshInterval
    }

    private func reload(mode: ReloadMode) async {
        let traceID = UUID().uuidString
        let startedAt = CFAbsoluteTimeGetCurrent()
        isLoading = true
        if mode == .initial, sections.isEmpty {
            statusMessage = nil
            showsInitialSkeleton = true
        }
        defer { isLoading = false }

        do {
            let codexHome = provider.codexHomeFolder.url
            if mode == .initial,
               allRows.isEmpty,
               let preloadingService = service as? any CodexSessionsTabPreloadingServicing
            {
                let preloadingTask = Task.detached(priority: .userInitiated) {
                    try preloadingService.loadProjectSkeletonSnapshot(codexHome: codexHome)
                }
                if let skeletonSnapshot = try? await preloadingTask.value {
                    apply(projectSkeletonSnapshot: skeletonSnapshot)
                }
            }
            if mode == .initial,
               let streamingService = service as? any CodexSessionsTabStreamingServicing
            {
                do {
                    let stream = streamingService.snapshotStream(
                        codexHome: codexHome,
                        batchSize: min(max(8, pageSize / 3), 16)
                    )
                    var receivedSnapshot = false
                    var streamedSessionIDs: Set<String> = []
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
                        streamedSessionIDs.formUnion(snapshot.sessions.map(\.id))
                        let removedSessionIDs: [String]
                        if snapshot.isComplete {
                            removedSessionIDs = Array(Set(rowsByID.keys).subtracting(streamedSessionIDs))
                        } else {
                            removedSessionIDs = []
                        }
                        apply(deltaPresentation: Self.makeDeltaPresentation(from: snapshot, removedSessionIDs: removedSessionIDs))
                        if !snapshot.sessions.isEmpty || snapshot.isComplete {
                            showsInitialSkeleton = false
                        }
                    }
                    if !receivedSnapshot {
                        apply(snapshotPresentation:
                            SessionPresentation(
                                availableProviderIDs: [],
                                rows: []
                            )
                        )
                    }
                } catch {
                    Self.emitPerformance(
                        operation: "load_stream_failed_fallback",
                        traceID: traceID,
                        providerID: provider.templateId ?? provider.id,
                        startedAt: startedAt,
                        extra: ["error": error.localizedDescription]
                    )
                    let presentation = try await loadSnapshotPresentation(codexHome: codexHome)
                    apply(snapshotPresentation: presentation)
                    showsInitialSkeleton = false
                }
            } else {
                let presentation = try await loadSnapshotPresentation(codexHome: codexHome)
                apply(snapshotPresentation: presentation)
                showsInitialSkeleton = false
            }
            Self.emitPerformance(
                operation: "load_complete",
                traceID: traceID,
                providerID: provider.templateId ?? provider.id,
                startedAt: startedAt,
                extra: [
                    "grouping_mode": groupingMode.rawValue,
                    "sort_mode": sortMode.rawValue,
                    "section_count": sections.count,
                    "session_count": totalSessionCount,
                    "visible_session_count": visibleSessionCount,
                ]
            )
            lastSuccessfulReloadAt = dateProvider()
        } catch {
            didStartInitialLoad = false
            sections = []
            availableTargetProviderIDs = []
            rowsByID = [:]
            allSectionStates = []
            projectSkeletons = []
            projectRowIDsBySectionID = [:]
            providerRowIDsBySectionID = [:]
            cancelUsageTasks()
            cancelTimelineTasks()
            usageBySessionID = [:]
            timelineBySessionID = [:]
            searchDebounceTask?.cancel()
            appliedSearchQuery = ""
            isProjectOrderLocked = false
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

    private func loadSnapshotPresentation(codexHome: URL) async throws -> SessionPresentation {
        let service = self.service
        return try await Task.detached(priority: .userInitiated) {
            let snapshot = try service.loadSnapshot(codexHome: codexHome)
            return Self.makePresentation(from: snapshot)
        }.value
    }

    func setGroupingMode(_ newValue: SessionGroupingMode) {
        guard groupingMode != newValue else { return }
        groupingMode = newValue
        preferencesStore.groupingMode = newValue
        rebuildSectionStates()
    }

    func setSortMode(_ newValue: SessionSortMode) {
        guard sortMode != newValue else { return }
        sortMode = newValue
        preferencesStore.sortMode = newValue
        rebuildSectionStates()
    }

    func targetProviders(for currentProviderID: String) -> [String] {
        availableTargetProviderIDs.filter { $0 != currentProviderID }
    }

    func selectSession(_ sessionID: String) {
        guard sections.flatMap(\.sessions).contains(where: { $0.id == sessionID }) else {
            return
        }
        if selectedSessionID == sessionID {
            primeSelectedSessionTimelineIfNeeded(forceRetry: true)
            return
        }
        updateSelectedSessionID(sessionID)
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

    func timelineState(for sessionID: String) -> SessionTimelineState {
        timelineBySessionID[sessionID] ?? .placeholder
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

    private func apply(snapshotPresentation presentation: SessionPresentation) {
        availableTargetProviderIDs = presentation.availableProviderIDs
        projectSkeletons = []
        resetRowIndexes()
        for row in presentation.rows {
            upsert(row: row)
        }
        let validSessionIDs = Set(rowsByID.keys)
        pruneUsageState(validSessionIDs: validSessionIDs)
        pruneTimelineState(validSessionIDs: validSessionIDs)
        isProjectOrderLocked = false
        rebuildSectionStates()
    }

    private func apply(projectSkeletonSnapshot: CodexSessionProjectSkeletonSnapshot) {
        availableTargetProviderIDs = projectSkeletonSnapshot.availableProviderIDs
        projectSkeletons = projectSkeletonSnapshot.projects
        isProjectOrderLocked = groupingMode == .project && !projectSkeletons.isEmpty
        if rowsByID.isEmpty {
            updateSelectedSessionID(nil)
        }
        rebuildSectionStates()
    }

    private func apply(deltaPresentation: SessionDeltaPresentation) {
        availableTargetProviderIDs = deltaPresentation.availableProviderIDs
        for sessionID in deltaPresentation.removedSessionIDs {
            removeSession(id: sessionID)
        }
        for row in deltaPresentation.rows {
            upsert(row: row)
        }
        let validSessionIDs = Set(rowsByID.keys)
        pruneUsageState(validSessionIDs: validSessionIDs)
        pruneTimelineState(validSessionIDs: validSessionIDs)
        if deltaPresentation.isComplete {
            isProjectOrderLocked = false
        }
        rebuildSectionStates()
    }

    private func rebuildSectionStates() {
        let isSearchActive = Self.isSearchActive(appliedSearchQuery)
        let validSectionStates: [SessionSectionState]

        if isSearchActive {
            let filteredRows = Self.filteredRows(from: allRows, searchQuery: appliedSearchQuery)
            allSectionStates = makeSectionStates(from: filteredRows, groupingMode: groupingMode)
            validSectionStates = currentSectionStatesForGrouping()
        } else {
            let sectionStates = currentSectionStatesForGrouping()
            allSectionStates = sectionStates
            validSectionStates = sectionStates
        }

        let validSectionIDs = Set(validSectionStates.map(\.id))
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
            let visibleSessions = visibleSessions(for: section, isExpanded: isExpanded)
            visibleSections.append(
                SessionSection(
                    id: section.id,
                    title: section.title,
                    titleSecondaryText: section.titleSecondaryText,
                    rewriteSourceLabel: section.rewriteSourceLabel,
                    rewriteSourceProviderID: section.rewriteSourceProviderID,
                    usageSessionIDs: section.sessions.map(\.id),
                    sessions: visibleSessions,
                    totalSessionCount: section.totalSessionCount,
                    editableThreadIDs: section.editableThreadIDs,
                    liveCount: section.liveCount,
                    archivedCount: section.archivedCount,
                    providerCount: section.providerCount,
                    isExpanded: isExpanded,
                    isPlaceholder: section.isPlaceholder
                )
            )
        }

        sections = visibleSections
        repairSelection()
        primeVisibleSessionUsages()
        primeSelectedSessionTimelineIfNeeded()
    }

    private func visibleSessions(
        for section: SessionSectionState,
        isExpanded: Bool
    ) -> [SessionRow] {
        if Self.isSearchActive(appliedSearchQuery) {
            return section.sessions
        }
        if isExpanded {
            return section.sessions
        }

        let liveSessions = section.sessions.filter { !$0.archived }
        let previewSource = liveSessions.isEmpty ? section.sessions : liveSessions
        return Array(previewSource.prefix(Self.defaultVisibleSessionCountPerSection))
    }

    private func currentSectionStatesForGrouping() -> [SessionSectionState] {
        switch groupingMode {
        case .project:
            let actualStates = makeProjectSectionStates()
            guard !projectSkeletons.isEmpty else { return actualStates }
            let merged = Self.mergeProjectSectionStates(
                actualStates: actualStates,
                projectSkeletons: projectSkeletons
            )
            if sortMode == .usage {
                return merged.sorted(by: sortSections(_:_:))
            }
            return merged

        case .provider:
            return makeProviderSectionStates()
        }
    }

    private func makeProjectSectionStates() -> [SessionSectionState] {
        let states = projectRowIDsBySectionID.compactMap { sectionID, rowIDs -> SessionSectionState? in
            let sessions = rowIDs.compactMap { rowsByID[$0] }
            guard !sessions.isEmpty else { return nil }
            let normalizedPath = Self.normalizedProjectPath(for: sessions.first?.cwd)
            let providerIDs = Set(sessions.map(\.modelProvider))
            let rewriteSourceProviderID = providerIDs.count == 1 ? providerIDs.first : nil
            let projectName = Self.projectDisplayName(for: normalizedPath)
            return makeSectionState(
                id: sectionID,
                title: projectName,
                titleSecondaryText: normalizedPath.map { $0 == "unknown-project" ? nil : $0 } ?? nil,
                rewriteSourceLabel: projectName,
                rewriteSourceProviderID: rewriteSourceProviderID,
                sessions: sessions,
                providerCountOverride: providerIDs.count,
                editableThreadIDsOverride: rewriteSourceProviderID == nil ? [] : nil
            )
        }
        return states.sorted(by: sortSections(_:_:))
    }

    private func makeProviderSectionStates() -> [SessionSectionState] {
        providerRowIDsBySectionID.compactMap { sectionID, rowIDs -> SessionSectionState? in
            let sessions = rowIDs.compactMap { rowsByID[$0] }
            guard let providerID = sessions.first?.modelProvider, !sessions.isEmpty else { return nil }
            return makeSectionState(
                id: sectionID,
                title: providerID,
                titleSecondaryText: nil,
                rewriteSourceLabel: providerID,
                rewriteSourceProviderID: providerID,
                sessions: sessions
            )
        }
        .sorted(by: sortSections(_:_:))
    }

    private func resetRowIndexes() {
        rowsByID = [:]
        projectRowIDsBySectionID = [:]
        providerRowIDsBySectionID = [:]
    }

    private func upsert(row: SessionRow) {
        if let existingRow = rowsByID[row.id] {
            remove(rowID: existingRow.id, fromSectionID: Self.projectSectionID(for: Self.normalizedProjectPath(for: existingRow.cwd)), buckets: &projectRowIDsBySectionID)
            remove(rowID: existingRow.id, fromSectionID: Self.providerSectionID(for: existingRow.modelProvider), buckets: &providerRowIDsBySectionID)
        }

        rowsByID[row.id] = row
        insert(rowID: row.id, intoSectionID: Self.projectSectionID(for: Self.normalizedProjectPath(for: row.cwd)), buckets: &projectRowIDsBySectionID)
        insert(rowID: row.id, intoSectionID: Self.providerSectionID(for: row.modelProvider), buckets: &providerRowIDsBySectionID)
    }

    private func removeSession(id: String) {
        guard let existingRow = rowsByID.removeValue(forKey: id) else { return }
        remove(rowID: existingRow.id, fromSectionID: Self.projectSectionID(for: Self.normalizedProjectPath(for: existingRow.cwd)), buckets: &projectRowIDsBySectionID)
        remove(rowID: existingRow.id, fromSectionID: Self.providerSectionID(for: existingRow.modelProvider), buckets: &providerRowIDsBySectionID)
    }

    private func remove(
        rowID: String,
        fromSectionID sectionID: String,
        buckets: inout [String: [String]]
    ) {
        guard var rowIDs = buckets[sectionID] else { return }
        rowIDs.removeAll { $0 == rowID }
        if rowIDs.isEmpty {
            buckets.removeValue(forKey: sectionID)
        } else {
            buckets[sectionID] = rowIDs
        }
    }

    private func insert(
        rowID: String,
        intoSectionID sectionID: String,
        buckets: inout [String: [String]]
    ) {
        var rowIDs = buckets[sectionID] ?? []
        rowIDs.removeAll { $0 == rowID }
        rowIDs.append(rowID)
        rowIDs.sort { lhsID, rhsID in
            guard let lhs = rowsByID[lhsID], let rhs = rowsByID[rhsID] else {
                return lhsID.localizedCaseInsensitiveCompare(rhsID) == .orderedAscending
            }
            return sortSessionRows(lhs, rhs)
        }
        buckets[sectionID] = rowIDs
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

    nonisolated private static func makeDeltaPresentation(
        from snapshot: CodexSessionSnapshotDelta,
        removedSessionIDs: [String]
    ) -> SessionDeltaPresentation {
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

        return SessionDeltaPresentation(
            availableProviderIDs: snapshot.availableProviderIDs,
            rows: rows,
            removedSessionIDs: removedSessionIDs,
            isComplete: snapshot.isComplete
        )
    }

    private func makeSectionStates(
        from rows: [SessionRow],
        groupingMode: SessionGroupingMode
    ) -> [SessionSectionState] {
        switch groupingMode {
        case .project:
            let grouped = Dictionary(grouping: rows) { row in
                Self.normalizedProjectPath(for: row.cwd) ?? "unknown-project"
            }
            return grouped
                .map { normalizedPath, value in
                    let sortedSessions = value.sorted(by: sortSessionRows(_:_:))
                    let providerIDs = Set(sortedSessions.map(\.modelProvider))
                    let rewriteSourceProviderID = providerIDs.count == 1 ? providerIDs.first : nil
                    let projectName = Self.projectDisplayName(for: normalizedPath)
                    return makeSectionState(
                        id: Self.projectSectionID(for: normalizedPath),
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

    private func makeSectionState(
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
        let usageOrdering = aggregateUsageOrdering(for: sortedSessions)
        return SessionSectionState(
            id: id,
            title: title,
            titleSecondaryText: titleSecondaryText,
            rewriteSourceLabel: rewriteSourceLabel,
            rewriteSourceProviderID: rewriteSourceProviderID,
            sessions: sortedSessions,
            totalSessionCount: sortedSessions.count,
            liveCount: sortedSessions.filter { !$0.archived }.count,
            archivedCount: sortedSessions.filter(\.archived).count,
            editableThreadIDs: editableThreadIDsOverride ?? sortedSessions.compactMap { row in
                guard row.editable else { return nil }
                return row.threadID
            },
            providerCount: providerCountOverride ?? Set(sortedSessions.map(\.modelProvider)).count,
            latestUpdatedAt: sortedSessions.first?.updatedAt,
            usageTotalTokens: usageOrdering.totalTokens,
            usageAvailabilityRank: usageOrdering.availabilityRank,
            isPlaceholder: false
        )
    }

    nonisolated private static func mergeProjectSectionStates(
        actualStates: [SessionSectionState],
        projectSkeletons: [CodexSessionProjectSkeleton]
    ) -> [SessionSectionState] {
        guard !projectSkeletons.isEmpty else { return actualStates }

        var actualByID = Dictionary(uniqueKeysWithValues: actualStates.map { ($0.id, $0) })
        var merged: [SessionSectionState] = []
        merged.reserveCapacity(max(projectSkeletons.count, actualStates.count))

        for skeleton in projectSkeletons {
            let sectionID = projectSectionID(for: skeleton.projectPath)
            if let actual = actualByID.removeValue(forKey: sectionID) {
                merged.append(actual)
            } else {
                merged.append(makePlaceholderSectionState(from: skeleton))
            }
        }

        if !actualByID.isEmpty {
            merged.append(
                contentsOf: actualByID.values.sorted { lhs, rhs in
                    let leftDate = lhs.latestUpdatedAt ?? .distantPast
                    let rightDate = rhs.latestUpdatedAt ?? .distantPast
                    if leftDate != rightDate {
                        return leftDate > rightDate
                    }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            )
        }

        return merged
    }

    nonisolated private static func makePlaceholderSectionState(
        from skeleton: CodexSessionProjectSkeleton
    ) -> SessionSectionState {
        let normalizedPath = skeleton.projectPath ?? "unknown-project"
        let projectName = projectDisplayName(for: normalizedPath == "unknown-project" ? nil : normalizedPath)
        return SessionSectionState(
            id: projectSectionID(for: skeleton.projectPath),
            title: projectName,
            titleSecondaryText: skeleton.projectPath,
            rewriteSourceLabel: projectName,
            rewriteSourceProviderID: nil,
            sessions: [],
            totalSessionCount: skeleton.liveCount + skeleton.archivedCount,
            liveCount: skeleton.liveCount,
            archivedCount: skeleton.archivedCount,
            editableThreadIDs: [],
            providerCount: 0,
            latestUpdatedAt: skeleton.latestUpdatedAt,
            usageTotalTokens: 0,
            usageAvailabilityRank: 1,
            isPlaceholder: true
        )
    }

    private func aggregateUsageOrdering(
        for sessions: [SessionRow]
    ) -> (totalTokens: Int, availabilityRank: Int) {
        var totalTokens = 0
        var hasLoadedUsage = false
        var hasPendingUsage = false

        for session in sessions {
            let ordering = usageOrderingValue(for: session.id)
            totalTokens += ordering.totalTokens
            if ordering.availabilityRank == 2 {
                hasLoadedUsage = true
            } else if ordering.availabilityRank == 1 {
                hasPendingUsage = true
            }
        }

        let availabilityRank: Int
        if hasLoadedUsage {
            availabilityRank = 2
        } else if hasPendingUsage {
            availabilityRank = 1
        } else {
            availabilityRank = 0
        }

        return (totalTokens, availabilityRank)
    }

    private func usageOrderingValue(
        for sessionID: String
    ) -> (totalTokens: Int, availabilityRank: Int) {
        switch usageBySessionID[sessionID] ?? .placeholder {
        case .loaded(let usage):
            return (max(0, usage.inputTokens + usage.outputTokens), 2)
        case .placeholder:
            return (0, 1)
        case .failed:
            return (0, 0)
        }
    }

    private func sortSections(_ lhs: SessionSectionState, _ rhs: SessionSectionState) -> Bool {
        if sortMode == .usage {
            if lhs.usageTotalTokens != rhs.usageTotalTokens {
                return lhs.usageTotalTokens > rhs.usageTotalTokens
            }
            if lhs.usageAvailabilityRank != rhs.usageAvailabilityRank {
                return lhs.usageAvailabilityRank > rhs.usageAvailabilityRank
            }
        }
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

    nonisolated private static func normalizedSearchQuery(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func scheduleSearchRebuild() {
        searchDebounceTask?.cancel()
        let normalizedQuery = Self.normalizedSearchQuery(searchQuery)
        guard !normalizedQuery.isEmpty else {
            appliedSearchQuery = ""
            rebuildSectionStates()
            return
        }

        let rawQuery = searchQuery
        let debounceNanoseconds = searchDebounceNanoseconds
        searchDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }

            await MainActor.run {
                guard let self else { return }
                guard Self.normalizedSearchQuery(self.searchQuery) == normalizedQuery else { return }
                self.appliedSearchQuery = rawQuery
                self.rebuildSectionStates()
            }
        }
    }

    nonisolated private static func isSearchActive(_ raw: String) -> Bool {
        !normalizedSearchQuery(raw).isEmpty
    }

    nonisolated private static func filteredRows(
        from rows: [SessionRow],
        searchQuery: String
    ) -> [SessionRow] {
        let normalizedQuery = normalizedSearchQuery(searchQuery)
        guard !normalizedQuery.isEmpty else { return rows }
        return rows.filter { matchesSearch($0, normalizedQuery: normalizedQuery) }
    }

    nonisolated private static func matchesSearch(
        _ row: SessionRow,
        normalizedQuery: String
    ) -> Bool {
        searchableTexts(for: row).contains { candidate in
            candidate.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    nonisolated private static func searchableTexts(for row: SessionRow) -> [String] {
        var texts: [String] = [
            row.title,
            row.displayID,
            row.modelProvider,
            inlineProviderLabel(for: row.modelProvider),
        ]
        if let summary = row.summary, !summary.isEmpty {
            texts.append(summary)
        }
        if let cwd = row.cwd, !cwd.isEmpty {
            texts.append(cwd)
        }
        return texts
    }

    private func sortSessionRows(_ lhs: SessionRow, _ rhs: SessionRow) -> Bool {
        if sortMode == .usage {
            let lhsUsage = usageOrderingValue(for: lhs.id)
            let rhsUsage = usageOrderingValue(for: rhs.id)
            if lhsUsage.totalTokens != rhsUsage.totalTokens {
                return lhsUsage.totalTokens > rhsUsage.totalTokens
            }
            if lhsUsage.availabilityRank != rhsUsage.availabilityRank {
                return lhsUsage.availabilityRank > rhsUsage.availabilityRank
            }
        }
        let leftDate = lhs.updatedAt ?? .distantPast
        let rightDate = rhs.updatedAt ?? .distantPast
        if leftDate != rightDate {
            return leftDate > rightDate
        }
        let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }
        return lhs.displayID.localizedCaseInsensitiveCompare(rhs.displayID) == .orderedAscending
    }

    nonisolated private static func normalizedProjectPath(for cwd: String?) -> String? {
        guard let cwd = cwd?.trimmingCharacters(in: .whitespacesAndNewlines), !cwd.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: cwd).standardizedFileURL.path
    }

    nonisolated private static func projectSectionID(for normalizedPath: String?) -> String {
        "project:\(normalizedPath ?? "unknown-project")"
    }

    nonisolated private static func providerSectionID(for providerID: String) -> String {
        "provider:\(providerID)"
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
        let sourceRows: [SessionRow]
        if sortMode == .usage {
            sourceRows = allSectionStates.flatMap(\.sessions)
        } else {
            sourceRows = sections.flatMap(\.sessions)
        }
        primeSessionUsages(for: sourceRows)
    }

    private func pruneUsageState(validSessionIDs: Set<String>) {
        for (sessionID, task) in usageTasks where !validSessionIDs.contains(sessionID) {
            task.cancel()
            usageTasks.removeValue(forKey: sessionID)
        }
        queuedUsageSessionIDs.removeAll { !validSessionIDs.contains($0) }
        queuedUsageSessionIDSet = queuedUsageSessionIDSet.intersection(validSessionIDs)
        usageBySessionID = usageBySessionID.filter { validSessionIDs.contains($0.key) }
    }

    private func pruneTimelineState(validSessionIDs: Set<String>) {
        for (sessionID, task) in timelineTasks where !validSessionIDs.contains(sessionID) {
            task.cancel()
            timelineTasks.removeValue(forKey: sessionID)
        }
        timelineRequestIDsBySessionID = timelineRequestIDsBySessionID.filter { validSessionIDs.contains($0.key) }
        timelineBySessionID = timelineBySessionID.filter { validSessionIDs.contains($0.key) }
    }

    private func cancelUsageTasks() {
        for task in usageTasks.values {
            task.cancel()
        }
        usageTasks.removeAll()
        queuedUsageSessionIDs.removeAll()
        queuedUsageSessionIDSet.removeAll()
        usageSortRebuildTask?.cancel()
        usageSortRebuildTask = nil
    }

    private func cancelTimelineTasks() {
        for task in timelineTasks.values {
            task.cancel()
        }
        timelineTasks.removeAll()
        timelineRequestIDsBySessionID.removeAll()
    }

    private func primeSessionUsages(for rows: [SessionRow]) {
        guard !rows.isEmpty else { return }

        for row in rows {
            guard usageBySessionID[row.id] == nil else { continue }
            guard usageTasks[row.id] == nil else { continue }
            guard queuedUsageSessionIDSet.contains(row.id) == false else { continue }
            usageBySessionID[row.id] = .placeholder
            queuedUsageSessionIDs.append(row.id)
            queuedUsageSessionIDSet.insert(row.id)
        }

        drainUsageQueueIfNeeded()
    }

    private func drainUsageQueueIfNeeded() {
        let codexHome = provider.codexHomeFolder.url
        let service = self.service

        while usageTasks.count < Self.usageSortingParallelism,
              let sessionID = queuedUsageSessionIDs.first {
            queuedUsageSessionIDs.removeFirst()
            queuedUsageSessionIDSet.remove(sessionID)

            guard let row = rowsByID[sessionID] else {
                usageBySessionID.removeValue(forKey: sessionID)
                continue
            }

            usageTasks[sessionID] = Task { [weak self] in
                let nextState: SessionUsageState
                do {
                    let rolloutPath = row.rolloutPath
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
                    if self.sortMode == .usage {
                        self.scheduleUsageSortRebuild()
                    }
                    self.drainUsageQueueIfNeeded()
                }
            }
        }
    }

    private func scheduleUsageSortRebuild() {
        usageSortRebuildTask?.cancel()
        usageSortRebuildTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
            } catch {
                return
            }
            await MainActor.run {
                guard let self, self.sortMode == .usage else { return }
                self.rebuildSectionStates()
            }
        }
    }

    private func primeSelectedSessionTimelineIfNeeded(forceRetry: Bool = false) {
        guard let selectedSessionID,
              timelineTasks[selectedSessionID] == nil,
              let row = rowsByID[selectedSessionID]
        else {
            return
        }

        if forceRetry {
            guard case .failed = timelineBySessionID[selectedSessionID] else {
                return
            }
        } else {
            guard timelineBySessionID[selectedSessionID] == nil else {
                return
            }
        }

        timelineBySessionID[selectedSessionID] = .placeholder
        let codexHome = provider.codexHomeFolder.url
        let service = self.service
        let rolloutPath = row.rolloutPath
        let requestID = UUID()
        timelineRequestIDsBySessionID[selectedSessionID] = requestID

        timelineTasks[selectedSessionID] = Task { [weak self] in
            let nextState: SessionTimelineState
            do {
                let timeline = try await Task.detached(priority: .utility) {
                    try service.loadSessionTimeline(codexHome: codexHome, rolloutPath: rolloutPath)
                }.value
                if let timeline {
                    nextState = .loaded(timeline)
                } else {
                    nextState = .failed
                }
            } catch {
                nextState = .failed
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled else { return }
                guard self.timelineRequestIDsBySessionID[selectedSessionID] == requestID else { return }
                self.timelineTasks[selectedSessionID] = nil
                self.timelineRequestIDsBySessionID[selectedSessionID] = nil
                guard self.rowsByID[selectedSessionID] != nil else {
                    self.timelineBySessionID.removeValue(forKey: selectedSessionID)
                    return
                }
                self.timelineBySessionID[selectedSessionID] = nextState
            }
        }
    }

    private func updateSelectedSessionID(_ sessionID: String?) {
        guard selectedSessionID != sessionID else { return }
        selectedSessionID = sessionID
        primeSelectedSessionTimelineIfNeeded()
    }

    private func repairSelection() {
        let visibleRows = sections.flatMap(\.sessions)
        guard !visibleRows.isEmpty || !rowsByID.isEmpty else {
            updateSelectedSessionID(nil)
            return
        }
        if Self.isSearchActive(appliedSearchQuery) {
            if let selectedSessionID,
               visibleRows.contains(where: { $0.id == selectedSessionID }) {
                return
            }
            updateSelectedSessionID(visibleRows.first?.id)
            return
        }
        if let selectedSessionID,
           rowsByID[selectedSessionID] != nil {
            return
        }
        updateSelectedSessionID(visibleRows.first?.id)
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

    private func installDiagnosticObservers() {
        let center = NotificationCenter.default
        _ = center.addObserver(
            forName: CodexSessionStore.warningNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated { [weak self] in
                self?.handleStoreWarningNotification(notification)
            }
        }
        _ = center.addObserver(
            forName: CodexSessionStore.performanceNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated { [weak self] in
                self?.handleStorePerformanceNotification(notification)
            }
        }
    }

    private func ensureDiagnosticObserversInstalled() {
        guard !didInstallDiagnosticObservers else { return }
        didInstallDiagnosticObservers = true
        installDiagnosticObservers()
    }

    private func handleStoreWarningNotification(_ notification: Notification) {
        guard matchesStoreNotification(notification.userInfo) else { return }
        guard let message = notification.userInfo?["message"] as? String, !message.isEmpty else {
            return
        }
        diagnosticWarningMessage = message
    }

    private func handleStorePerformanceNotification(_ notification: Notification) {
        guard matchesStoreNotification(notification.userInfo) else { return }
        guard let operation = notification.userInfo?["operation"] as? String else { return }

        switch operation {
        case "snapshot_stream_failed":
            let error = (notification.userInfo?["error"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let error, !error.isEmpty {
                diagnosticPerformanceMessage = error
            } else {
                diagnosticPerformanceMessage = "Session snapshot stream failed."
            }

        case "load_snapshot", "snapshot_stream_complete":
            let elapsedMS = notification.userInfo?["elapsed_ms"] as? Int ?? 0
            if elapsedMS >= Self.slowStoreOperationThresholdMS {
                let sessionCount = notification.userInfo?["session_count"] as? Int ?? totalSessionCount
                diagnosticPerformanceMessage = String(
                    format: NSLocalizedString(
                        "codex.sessions.status.slow_scan",
                        value: "Session scan processed %d sessions in %d ms.",
                        comment: "Codex sessions slow scan diagnostic message"
                    ),
                    sessionCount,
                    elapsedMS
                )
            } else {
                diagnosticPerformanceMessage = nil
            }

        default:
            break
        }
    }

    private func matchesStoreNotification(_ userInfo: [AnyHashable: Any]?) -> Bool {
        guard let userInfo else { return false }
        let expectedPath = provider.codexHomeFolder.url.standardizedFileURL.path
        if let path = userInfo["codex_home_path"] as? String {
            let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
            return normalizedPath == expectedPath
        }
        if let message = userInfo["message"] as? String {
            return message.contains(expectedPath)
        }
        return false
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
