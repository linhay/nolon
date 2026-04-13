import Foundation
import OSLog
import SQLite3
import STFilePath

public struct CodexSessionRecord: Sendable, Equatable, Identifiable {
    public let id: String
    public let threadID: String?
    public let title: String?
    public let summary: String?
    public let modelProvider: String
    public let archived: Bool
    public let rolloutPath: String
    public let cwd: String?
    public let updatedAt: Date?
    public let stateRowCount: Int
    public let editable: Bool

    public init(
        id: String,
        threadID: String?,
        title: String?,
        summary: String?,
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
        self.modelProvider = modelProvider
        self.archived = archived
        self.rolloutPath = rolloutPath
        self.cwd = cwd
        self.updatedAt = updatedAt
        self.stateRowCount = stateRowCount
        self.editable = editable
    }
}

public struct CodexSessionSnapshot: Sendable, Equatable {
    public let sessions: [CodexSessionRecord]
    public let availableProviderIDs: [String]

    public init(sessions: [CodexSessionRecord], availableProviderIDs: [String]) {
        self.sessions = sessions
        self.availableProviderIDs = availableProviderIDs
    }
}

public struct CodexSessionProviderRewriteRequest: Sendable, Equatable {
    public let threadIDs: [String]
    public let targetProviderID: String

    public init(threadIDs: [String], targetProviderID: String) {
        self.threadIDs = threadIDs
        self.targetProviderID = targetProviderID
    }
}

public struct CodexSessionRewritePreview: Sendable, Equatable {
    public let sessionCount: Int
    public let liveSessionCount: Int
    public let archivedSessionCount: Int
    public let stateRowCount: Int

    public init(
        sessionCount: Int,
        liveSessionCount: Int,
        archivedSessionCount: Int,
        stateRowCount: Int
    ) {
        self.sessionCount = sessionCount
        self.liveSessionCount = liveSessionCount
        self.archivedSessionCount = archivedSessionCount
        self.stateRowCount = stateRowCount
    }
}

public struct CodexSessionRewriteResult: Sendable, Equatable {
    public let preview: CodexSessionRewritePreview
    public let liveRolloutFilesUpdated: Int
    public let archivedRolloutFilesUpdated: Int
    public let stateRowsUpdated: Int
    public let failures: [String]

    public init(
        preview: CodexSessionRewritePreview,
        liveRolloutFilesUpdated: Int,
        archivedRolloutFilesUpdated: Int,
        stateRowsUpdated: Int,
        failures: [String]
    ) {
        self.preview = preview
        self.liveRolloutFilesUpdated = liveRolloutFilesUpdated
        self.archivedRolloutFilesUpdated = archivedRolloutFilesUpdated
        self.stateRowsUpdated = stateRowsUpdated
        self.failures = failures
    }
}

public struct CodexSessionProviderMigrationReport: Sendable, Equatable {
    public let liveRolloutFilesUpdated: Int
    public let archivedRolloutFilesUpdated: Int
    public let stateRowsUpdated: Int

    public init(
        liveRolloutFilesUpdated: Int,
        archivedRolloutFilesUpdated: Int,
        stateRowsUpdated: Int
    ) {
        self.liveRolloutFilesUpdated = liveRolloutFilesUpdated
        self.archivedRolloutFilesUpdated = archivedRolloutFilesUpdated
        self.stateRowsUpdated = stateRowsUpdated
    }
}

public struct CodexSessionStore: Sendable {
    public static let warningNotification = Notification.Name("CodexSessionStore.warning")
    public static let performanceNotification = Notification.Name("CodexSessionStore.performance")
    private static let logger = Logger(subsystem: "com.nolon", category: "CodexSessionStore")
    private static let rolloutRewriteParallelism = 6

    private struct StateThreadRow: Sendable, Equatable {
        let threadID: String
        let title: String?
        let modelProvider: String
        let updatedAt: Date?
        let archived: Bool
    }

    private struct StateIndex: Sendable, Equatable {
        struct ThreadState: Sendable, Equatable {
            let latestRow: StateThreadRow?
            let rowCount: Int
        }

        let threadsByID: [String: ThreadState]
    }

    private struct SessionIndex: Sendable, Equatable {
        let threadNamesByID: [String: String]
    }

    private struct RewriteRolloutTargets: Sendable, Equatable {
        let liveFileURLs: [URL]
        let archivedFileURLs: [URL]
    }

    private final class RolloutRewriteAccumulator: @unchecked Sendable {
        private let lock = NSLock()
        private var updatedFiles = 0
        private var capturedError: Error?

        func shouldSkip() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return capturedError != nil
        }

        func recordUpdate() {
            lock.lock()
            updatedFiles += 1
            lock.unlock()
        }

        func recordError(_ error: Error) {
            lock.lock()
            if capturedError == nil {
                capturedError = error
            }
            lock.unlock()
        }

        func finish() throws -> Int {
            lock.lock()
            defer { lock.unlock() }
            if let capturedError {
                throw capturedError
            }
            return updatedFiles
        }
    }

    private let defaultProviderID: String

    public init(defaultProviderID: String = "openai") {
        self.defaultProviderID = Self.normalizedProviderID(defaultProviderID) ?? "openai"
    }

    public func loadSnapshot(codexHome: URL) throws -> CodexSessionSnapshot {
        try loadSnapshot(codexHome: STFolder(codexHome))
    }

    public func snapshotStream(
        codexHome: URL,
        batchSize: Int = 24
    ) -> AsyncThrowingStream<CodexSessionSnapshot, Error> {
        snapshotStream(codexHome: STFolder(codexHome), batchSize: batchSize)
    }

    public func snapshotStream(
        codexHome: STFolder,
        batchSize: Int = 24
    ) -> AsyncThrowingStream<CodexSessionSnapshot, Error> {
        let effectiveBatchSize = max(1, batchSize)

        return AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let traceID = UUID().uuidString
                let startedAt = CFAbsoluteTimeGetCurrent()
                do {
                    let stateIndex = try loadStateIndex(in: codexHome)
                    let sessionIndex = loadSessionIndex(in: codexHome)
                    let scannedFiles = CodexSessionScanner.scanFiles(codexHome: codexHome, includeArchived: true)
                    let availableProviderIDs = loadAvailableProviderIDs(codexHome: codexHome)
                    var yieldedBatchCount = 0

                    guard !scannedFiles.isEmpty else {
                        Self.emitPerformance(
                            operation: "snapshot_stream_complete",
                            traceID: traceID,
                            startedAt: startedAt,
                            extra: [
                                "available_provider_count": availableProviderIDs.count,
                                "batch_count": 0,
                                "batch_size": effectiveBatchSize,
                                "scanned_file_count": 0,
                                "session_count": 0,
                                "state_thread_count": stateIndex.threadsByID.count,
                            ]
                        )
                        continuation.yield(
                            CodexSessionSnapshot(
                                sessions: [],
                                availableProviderIDs: availableProviderIDs
                            )
                        )
                        continuation.finish()
                        return
                    }

                    var sessions: [CodexSessionRecord] = []
                    sessions.reserveCapacity(scannedFiles.count)

                    for startIndex in stride(from: 0, to: scannedFiles.count, by: effectiveBatchSize) {
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }

                        let endIndex = min(scannedFiles.count, startIndex + effectiveBatchSize)
                        let batch = scannedFiles[startIndex..<endIndex].compactMap { scannedFile in
                            makeSessionRecord(
                                file: scannedFile,
                                stateIndex: stateIndex,
                                sessionIndex: sessionIndex
                            )
                        }
                        let sortedBatch = batch.sorted(by: Self.sortSessions(_:_:))
                        sessions = Self.mergeSortedSessions(existing: sessions, incoming: sortedBatch)
                        yieldedBatchCount += 1

                        continuation.yield(
                            CodexSessionSnapshot(
                                sessions: sessions,
                                availableProviderIDs: availableProviderIDs
                            )
                        )
                    }

                    Self.emitPerformance(
                        operation: "snapshot_stream_complete",
                        traceID: traceID,
                        startedAt: startedAt,
                        extra: [
                            "available_provider_count": availableProviderIDs.count,
                            "batch_count": yieldedBatchCount,
                            "batch_size": effectiveBatchSize,
                            "scanned_file_count": scannedFiles.count,
                            "session_count": sessions.count,
                            "state_thread_count": stateIndex.threadsByID.count,
                        ]
                    )
                    continuation.finish()
                } catch {
                    Self.emitPerformance(
                        operation: "snapshot_stream_failed",
                        traceID: traceID,
                        startedAt: startedAt,
                        extra: ["error": error.localizedDescription]
                    )
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func loadSnapshot(codexHome: STFolder) throws -> CodexSessionSnapshot {
        let traceID = UUID().uuidString
        let startedAt = CFAbsoluteTimeGetCurrent()
        let stateIndex = try loadStateIndex(in: codexHome)
        let sessionIndex = loadSessionIndex(in: codexHome)
        let scannedFiles = CodexSessionScanner.scanFiles(codexHome: codexHome, includeArchived: true)

        let sessions = scannedFiles.compactMap { scannedFile in
            makeSessionRecord(
                file: scannedFile,
                stateIndex: stateIndex,
                sessionIndex: sessionIndex
            )
        }
        .sorted(by: Self.sortSessions(_:_:))

        let snapshot = CodexSessionSnapshot(
            sessions: sessions,
            availableProviderIDs: loadAvailableProviderIDs(codexHome: codexHome)
        )
        Self.emitPerformance(
            operation: "load_snapshot",
            traceID: traceID,
            startedAt: startedAt,
            extra: [
                "available_provider_count": snapshot.availableProviderIDs.count,
                "scanned_file_count": scannedFiles.count,
                "session_count": snapshot.sessions.count,
                "state_thread_count": stateIndex.threadsByID.count,
            ]
        )
        return snapshot
    }

    public func previewRewrite(
        codexHome: URL,
        request: CodexSessionProviderRewriteRequest
    ) throws -> CodexSessionRewritePreview {
        try previewRewrite(codexHome: STFolder(codexHome), request: request)
    }

    public func previewRewrite(
        codexHome: STFolder,
        request: CodexSessionProviderRewriteRequest
    ) throws -> CodexSessionRewritePreview {
        let normalizedThreadIDs = Self.normalizedThreadIDs(request.threadIDs)
        guard !normalizedThreadIDs.isEmpty else {
            return .init(sessionCount: 0, liveSessionCount: 0, archivedSessionCount: 0, stateRowCount: 0)
        }

        let snapshot = try loadSnapshot(codexHome: codexHome)
        let selectedSessions = snapshot.sessions.filter { session in
            guard let threadID = session.threadID?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return normalizedThreadIDs.contains(threadID)
        }

        return .init(
            sessionCount: selectedSessions.count,
            liveSessionCount: selectedSessions.filter { !$0.archived }.count,
            archivedSessionCount: selectedSessions.filter(\.archived).count,
            stateRowCount: selectedSessions.reduce(into: 0) { partialResult, session in
                partialResult += session.stateRowCount
            }
        )
    }

    public func rewriteProviders(
        codexHome: URL,
        request: CodexSessionProviderRewriteRequest,
        confirmedPreview: CodexSessionRewritePreview? = nil
    ) throws -> CodexSessionRewriteResult {
        try rewriteProviders(
            codexHome: STFolder(codexHome),
            request: request,
            confirmedPreview: confirmedPreview
        )
    }

    public func rewriteProviders(
        codexHome: STFolder,
        request: CodexSessionProviderRewriteRequest,
        confirmedPreview: CodexSessionRewritePreview? = nil
    ) throws -> CodexSessionRewriteResult {
        let traceID = UUID().uuidString
        let startedAt = CFAbsoluteTimeGetCurrent()
        let normalizedTarget = Self.normalizedProviderID(request.targetProviderID)
        let normalizedThreadIDs = Self.normalizedThreadIDs(request.threadIDs)
        guard let normalizedTarget, !normalizedThreadIDs.isEmpty else {
            return .init(
                preview: .init(sessionCount: 0, liveSessionCount: 0, archivedSessionCount: 0, stateRowCount: 0),
                liveRolloutFilesUpdated: 0,
                archivedRolloutFilesUpdated: 0,
                stateRowsUpdated: 0,
                failures: []
            )
        }

        Self.emitRewritePhase(traceID: traceID, phase: "preview", status: "started")
        let previewStartedAt = CFAbsoluteTimeGetCurrent()
        let preview = try confirmedPreview ?? previewRewrite(
            codexHome: codexHome,
            request: .init(threadIDs: Array(normalizedThreadIDs), targetProviderID: normalizedTarget)
        )
        let previewElapsedMs = Self.elapsedMilliseconds(since: previewStartedAt)
        Self.emitRewritePhase(
            traceID: traceID,
            phase: "preview",
            status: "completed",
            extra: ["elapsed_ms": previewElapsedMs]
        )

        let rolloutTargets = try resolveRewriteRolloutTargets(
            in: codexHome,
            matchingThreadIDs: normalizedThreadIDs
        )

        var liveRolloutFilesUpdated = 0
        var archivedRolloutFilesUpdated = 0
        var failures: [String] = []
        Self.emitRewritePhase(traceID: traceID, phase: "live_rollout", status: "started")
        let liveRolloutStartedAt = CFAbsoluteTimeGetCurrent()

        do {
            let updated = try rewriteRolloutFiles(
                at: rolloutTargets.liveFileURLs,
                matchingThreadIDs: normalizedThreadIDs,
                targetProviderID: normalizedTarget
            )
            liveRolloutFilesUpdated = updated
        } catch {
            failures.append("live rollout files: \(error.localizedDescription)")
        }
        let liveRolloutElapsedMs = Self.elapsedMilliseconds(since: liveRolloutStartedAt)
        Self.emitRewritePhase(
            traceID: traceID,
            phase: "live_rollout",
            status: "completed",
            extra: [
                "elapsed_ms": liveRolloutElapsedMs,
                "updated_count": liveRolloutFilesUpdated,
            ]
        )

        Self.emitRewritePhase(traceID: traceID, phase: "archived_rollout", status: "started")
        let archivedRolloutStartedAt = CFAbsoluteTimeGetCurrent()
        do {
            let updated = try rewriteRolloutFiles(
                at: rolloutTargets.archivedFileURLs,
                matchingThreadIDs: normalizedThreadIDs,
                targetProviderID: normalizedTarget
            )
            archivedRolloutFilesUpdated = updated
        } catch {
            failures.append("archived rollout files: \(error.localizedDescription)")
        }
        let archivedRolloutElapsedMs = Self.elapsedMilliseconds(since: archivedRolloutStartedAt)
        Self.emitRewritePhase(
            traceID: traceID,
            phase: "archived_rollout",
            status: "completed",
            extra: [
                "elapsed_ms": archivedRolloutElapsedMs,
                "updated_count": archivedRolloutFilesUpdated,
            ]
        )

        let stateRowsUpdated: Int
        Self.emitRewritePhase(traceID: traceID, phase: "state_db", status: "started")
        let stateDBStartedAt = CFAbsoluteTimeGetCurrent()
        do {
            stateRowsUpdated = try rewriteStateDatabases(
                in: codexHome,
                matchingThreadIDs: normalizedThreadIDs,
                targetProviderID: normalizedTarget
            )
        } catch {
            failures.append("state db: \(error.localizedDescription)")
            stateRowsUpdated = 0
        }
        let stateDBElapsedMs = Self.elapsedMilliseconds(since: stateDBStartedAt)
        Self.emitRewritePhase(
            traceID: traceID,
            phase: "state_db",
            status: "completed",
            extra: [
                "elapsed_ms": stateDBElapsedMs,
                "updated_count": stateRowsUpdated,
            ]
        )

        Self.emitRewritePhase(traceID: traceID, phase: "verify", status: "started")
        let verifyStartedAt = CFAbsoluteTimeGetCurrent()
        failures.append(
            contentsOf: verifyRewriteConsistency(
                in: codexHome,
                matchingThreadIDs: normalizedThreadIDs,
                targetProviderID: normalizedTarget
            )
        )
        let verifyElapsedMs = Self.elapsedMilliseconds(since: verifyStartedAt)
        Self.emitRewritePhase(
            traceID: traceID,
            phase: "verify",
            status: "completed",
            extra: [
                "elapsed_ms": verifyElapsedMs,
                "failure_count": failures.count,
            ]
        )

        let result = CodexSessionRewriteResult(
            preview: preview,
            liveRolloutFilesUpdated: liveRolloutFilesUpdated,
            archivedRolloutFilesUpdated: archivedRolloutFilesUpdated,
            stateRowsUpdated: stateRowsUpdated,
            failures: failures
        )
        Self.emitPerformance(
            operation: "rewrite_providers",
            traceID: traceID,
            startedAt: startedAt,
            extra: [
                "archived_rollout_files_updated": result.archivedRolloutFilesUpdated,
                "archived_rollout_elapsed_ms": archivedRolloutElapsedMs,
                "failure_count": result.failures.count,
                "live_rollout_elapsed_ms": liveRolloutElapsedMs,
                "live_rollout_files_updated": result.liveRolloutFilesUpdated,
                "preview_elapsed_ms": previewElapsedMs,
                "preview_session_count": result.preview.sessionCount,
                "preview_state_row_count": result.preview.stateRowCount,
                "state_db_elapsed_ms": stateDBElapsedMs,
                "state_rows_updated": result.stateRowsUpdated,
                "thread_count": normalizedThreadIDs.count,
                "verify_elapsed_ms": verifyElapsedMs,
            ]
        )
        return result
    }

    public func migrateProviders(
        codexHome: URL,
        sourceProviderIDs: [String],
        targetProviderID: String
    ) throws -> CodexSessionProviderMigrationReport {
        try migrateProviders(
            codexHome: STFolder(codexHome),
            sourceProviderIDs: sourceProviderIDs,
            targetProviderID: targetProviderID
        )
    }

    public func migrateProviders(
        codexHome: STFolder,
        sourceProviderIDs: [String],
        targetProviderID: String
    ) throws -> CodexSessionProviderMigrationReport {
        let normalizedSources = Set(sourceProviderIDs.compactMap(Self.normalizedProviderID))
        guard let normalizedTarget = Self.normalizedProviderID(targetProviderID) else {
            return .init(liveRolloutFilesUpdated: 0, archivedRolloutFilesUpdated: 0, stateRowsUpdated: 0)
        }
        let filteredSources = normalizedSources.subtracting([normalizedTarget])
        guard !filteredSources.isEmpty else {
            return .init(liveRolloutFilesUpdated: 0, archivedRolloutFilesUpdated: 0, stateRowsUpdated: 0)
        }

        let liveRolloutFilesUpdated = try rewriteRolloutFiles(
            in: codexHome.folder("sessions"),
            matchingProviderIDs: filteredSources,
            targetProviderID: normalizedTarget
        )
        let archivedRolloutFilesUpdated = try rewriteRolloutFiles(
            in: codexHome.folder("archived_sessions"),
            matchingProviderIDs: filteredSources,
            targetProviderID: normalizedTarget
        )
        let stateRowsUpdated = try rewriteStateDatabases(
            in: codexHome,
            matchingProviderIDs: filteredSources,
            targetProviderID: normalizedTarget
        )
        return .init(
            liveRolloutFilesUpdated: liveRolloutFilesUpdated,
            archivedRolloutFilesUpdated: archivedRolloutFilesUpdated,
            stateRowsUpdated: stateRowsUpdated
        )
    }

    private func makeSessionRecord(
        file: CodexSessionScanner.ScannedFile,
        stateIndex: StateIndex,
        sessionIndex: SessionIndex
    ) -> CodexSessionRecord? {
        guard let sessionMeta = CodexSessionScanner.readSessionMeta(from: file) else {
            return nil
        }

        let trimmedThreadID = sessionMeta.threadID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let stateThread = trimmedThreadID.flatMap { stateIndex.threadsByID[$0] }
        let stateRow = stateThread?.latestRow

        let title = stateRow?.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? trimmedThreadID.flatMap { sessionIndex.threadNamesByID[$0] }?.nilIfEmpty
        let modelProvider = CodexSessionScanner.normalizedProviderID(sessionMeta.modelProvider)
            ?? stateRow.flatMap { Self.normalizedProviderID($0.modelProvider) }
            ?? defaultProviderID
        let archived = file.archived
        let updatedAt = stateRow?.updatedAt
            ?? Self.parseISO8601(sessionMeta.timestamp)
            ?? Self.fileModificationDate(path: file.file.path)
        let relativePath = file.relativePath

        return .init(
            id: relativePath,
            threadID: trimmedThreadID,
            title: title,
            summary: nil,
            modelProvider: modelProvider,
            archived: archived,
            rolloutPath: relativePath,
            cwd: sessionMeta.cwd,
            updatedAt: updatedAt,
            stateRowCount: stateThread?.rowCount ?? 0,
            editable: trimmedThreadID != nil
        )
    }

    private func loadAvailableProviderIDs(codexHome: STFolder) -> [String] {
        let configFile = codexHome.file("config.toml")
        guard configFile.isExists, let raw = try? configFile.read() else {
            return [defaultProviderID]
        }

        var result: [String] = []
        var seen: Set<String> = []

        func append(_ rawValue: String?) {
            guard let normalized = Self.normalizedProviderID(rawValue),
                  seen.insert(normalized).inserted
            else {
                return
            }
            result.append(normalized)
        }

        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            append(Self.extractQuotedValue(from: line, key: "model_provider"))
            append(Self.extractModelProviderSectionID(from: line))
        }
        if result.isEmpty {
            let message = "CodexSessionStore: no provider IDs were parsed from \(configFile.url.path). Falling back to default provider \(defaultProviderID)."
            NSLog("%@", message)
            NotificationCenter.default.post(
                name: Self.warningNotification,
                object: nil,
                userInfo: ["message": message]
            )
        }
        append(defaultProviderID)
        return result
    }

    private func loadStateIndex(in codexHome: STFolder) throws -> StateIndex {
        let databaseFiles = try stateDatabaseFiles(in: codexHome)
        var latestRowsByThreadID: [String: StateThreadRow] = [:]
        var rowCountsByThreadID: [String: Int] = [:]

        for databaseFile in databaseFiles {
            for row in try loadThreadRows(from: databaseFile.url) {
                rowCountsByThreadID[row.threadID, default: 0] += 1
                if let existing = latestRowsByThreadID[row.threadID] {
                    if Self.isStateRow(row, newerThan: existing) {
                        latestRowsByThreadID[row.threadID] = row
                    }
                } else {
                    latestRowsByThreadID[row.threadID] = row
                }
            }
        }

        let threadsByID = rowCountsByThreadID.reduce(into: [String: StateIndex.ThreadState]()) { partialResult, item in
            let (threadID, rowCount) = item
            partialResult[threadID] = .init(
                latestRow: latestRowsByThreadID[threadID],
                rowCount: rowCount
            )
        }

        return .init(threadsByID: threadsByID)
    }

    private func loadSessionIndex(in codexHome: STFolder) -> SessionIndex {
        let file = codexHome.file("session_index.jsonl")
        guard file.isExists, let raw = try? file.read() else {
            return .init(threadNamesByID: [:])
        }

        var threadNamesByID: [String: String] = [:]
        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let threadID = (object["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                  let threadName = (object["thread_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            else {
                continue
            }
            threadNamesByID[threadID] = threadName
        }

        return .init(threadNamesByID: threadNamesByID)
    }

    private func loadThreadRows(from databaseURL: URL) throws -> [StateThreadRow] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(
                domain: "CodexSessionStore.SQLite",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex state database." : message]
            )
        }
        defer { sqlite3_close(db) }

        guard try sqliteTableExists(db: db, table: "threads") else { return [] }

        let sql = "SELECT id, title, model_provider, updated_at, archived FROM threads;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(
                domain: "CodexSessionStore.SQLite",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Failed to read Codex threads." : message]
            )
        }
        defer { sqlite3_finalize(statement) }

        var rows: [StateThreadRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idCString = sqlite3_column_text(statement, 0) else { continue }
            let threadID = String(cString: idCString)
            let title = sqlite3_column_text(statement, 1).map { String(cString: $0) }
            let modelProvider = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? defaultProviderID
            let updatedAt = sqlite3_column_type(statement, 3) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 3)))
            let archived = sqlite3_column_int(statement, 4) != 0
            rows.append(.init(
                threadID: threadID,
                title: title,
                modelProvider: Self.normalizedProviderID(modelProvider) ?? defaultProviderID,
                updatedAt: updatedAt,
                archived: archived
            ))
        }
        return rows
    }

    private func rewriteRolloutFiles(
        at fileURLs: [URL],
        matchingThreadIDs: Set<String>,
        targetProviderID: String
    ) throws -> Int {
        guard !fileURLs.isEmpty else { return 0 }
        guard !matchingThreadIDs.isEmpty else { return 0 }
        guard fileURLs.count > 1 else {
            return try fileURLs.reduce(into: 0) { partialResult, url in
                if try rewriteRolloutFile(
                    at: url,
                    targetProviderID: targetProviderID,
                    matchingThreadIDs: matchingThreadIDs
                ) {
                    partialResult += 1
                }
            }
        }

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = min(Self.rolloutRewriteParallelism, fileURLs.count)
        let accumulator = RolloutRewriteAccumulator()

        for url in fileURLs {
            queue.addOperation {
                if accumulator.shouldSkip() { return }
                do {
                    let changed = try rewriteRolloutFile(
                        at: url,
                        targetProviderID: targetProviderID,
                        matchingThreadIDs: matchingThreadIDs
                    )
                    guard changed else { return }
                    accumulator.recordUpdate()
                } catch {
                    accumulator.recordError(error)
                }
            }
        }

        queue.waitUntilAllOperationsAreFinished()
        return try accumulator.finish()
    }

    private func resolveRewriteRolloutTargets(
        in codexHome: STFolder,
        matchingThreadIDs: Set<String>
    ) throws -> RewriteRolloutTargets {
        guard !matchingThreadIDs.isEmpty else {
            return .init(liveFileURLs: [], archivedFileURLs: [])
        }

        let matchingFiles = CodexSessionScanner.scanFiles(codexHome: codexHome, includeArchived: true).filter { scannedFile in
            guard let threadID = CodexSessionScanner.readSessionMeta(from: scannedFile)?.threadID?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !threadID.isEmpty
            else {
                return false
            }
            return matchingThreadIDs.contains(threadID)
        }

        let liveFileURLs = matchingFiles
            .filter { !$0.archived }
            .map { $0.file.url.standardizedFileURL }
        let archivedFileURLs = matchingFiles
            .filter(\.archived)
            .map { $0.file.url.standardizedFileURL }

        return .init(
            liveFileURLs: Array(Set(liveFileURLs)),
            archivedFileURLs: Array(Set(archivedFileURLs))
        )
    }

    private func rewriteRolloutFiles(
        in root: STFolder,
        matchingProviderIDs: Set<String>,
        targetProviderID: String
    ) throws -> Int {
        guard root.isExists else { return 0 }
        guard !matchingProviderIDs.isEmpty else { return 0 }
        guard let enumerator = FileManager.default.enumerator(
            at: root.url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var updatedFiles = 0
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true, url.pathExtension.lowercased() == "jsonl" else {
                continue
            }
            if try rewriteRolloutFile(
                at: url,
                targetProviderID: targetProviderID,
                matchingProviderIDs: matchingProviderIDs
            ) {
                updatedFiles += 1
            }
        }
        return updatedFiles
    }

    private func rewriteRolloutFile(
        at url: URL,
        targetProviderID: String,
        matchingThreadIDs: Set<String>
    ) throws -> Bool {
        let original = try String(contentsOf: url, encoding: .utf8)
        guard let rewrittenContent = try rewriteFirstSessionMetaLine(
            in: original,
            rewriter: { line in
                try rewriteSessionMetaLine(
                    line,
                    targetProviderID: targetProviderID,
                    matchingThreadIDs: matchingThreadIDs
                )
            }
        ) else {
            return false
        }
        try rewrittenContent.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    private func rewriteRolloutFile(
        at url: URL,
        targetProviderID: String,
        matchingProviderIDs: Set<String>
    ) throws -> Bool {
        let original = try String(contentsOf: url, encoding: .utf8)
        guard let rewrittenContent = try rewriteFirstSessionMetaLine(
            in: original,
            rewriter: { line in
                try rewriteSessionMetaLine(
                    line,
                    targetProviderID: targetProviderID,
                    matchingProviderIDs: matchingProviderIDs
                )
            }
        ) else {
            return false
        }
        try rewrittenContent.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    private func rewriteSessionMetaLine(
        _ line: String,
        targetProviderID: String,
        matchingThreadIDs: Set<String>
    ) throws -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["type"] as? String) == "session_meta",
              var payload = object["payload"] as? [String: Any],
              let threadID = payload["id"] as? String
        else {
            return nil
        }

        let normalizedThreadID = threadID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard matchingThreadIDs.contains(normalizedThreadID) else { return nil }

        let currentProviderID = Self.normalizedProviderID(payload["model_provider"] as? String) ?? defaultProviderID
        guard currentProviderID != targetProviderID else { return nil }

        payload["model_provider"] = targetProviderID
        var rewrittenObject = object
        rewrittenObject["payload"] = payload
        let rewrittenData = try JSONSerialization.data(withJSONObject: rewrittenObject, options: [.sortedKeys])
        return String(data: rewrittenData, encoding: .utf8)
    }

    private func rewriteFirstSessionMetaLine(
        in original: String,
        rewriter: (String) throws -> String?
    ) throws -> String? {
        var lineStart = original.startIndex

        while lineStart < original.endIndex {
            let lineEnd = original[lineStart...].firstIndex(of: "\n") ?? original.endIndex
            let line = String(original[lineStart..<lineEnd])
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmed.isEmpty {
                guard let rewrittenLine = try rewriter(line), rewrittenLine != line else {
                    return nil
                }

                var rewritten = String(original[..<lineStart])
                rewritten += rewrittenLine
                if lineEnd < original.endIndex {
                    rewritten += String(original[lineEnd...])
                }
                return rewritten
            }

            guard lineEnd < original.endIndex else { break }
            lineStart = original.index(after: lineEnd)
        }

        return nil
    }

    private func rewriteSessionMetaLine(
        _ line: String,
        targetProviderID: String,
        matchingProviderIDs: Set<String>
    ) throws -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["type"] as? String) == "session_meta",
              var payload = object["payload"] as? [String: Any]
        else {
            return nil
        }

        let currentProviderID = Self.normalizedProviderID(payload["model_provider"] as? String)
        let matchesExplicitProvider = currentProviderID.map(matchingProviderIDs.contains) ?? false
        let matchesDefaultProvider = currentProviderID == nil && matchingProviderIDs.contains(defaultProviderID)
        guard matchesExplicitProvider || matchesDefaultProvider else { return nil }

        payload["model_provider"] = targetProviderID
        var rewrittenObject = object
        rewrittenObject["payload"] = payload
        let rewrittenData = try JSONSerialization.data(withJSONObject: rewrittenObject, options: [.sortedKeys])
        return String(data: rewrittenData, encoding: .utf8)
    }

    private func rewriteStateDatabases(
        in codexHome: STFolder,
        matchingThreadIDs: Set<String>,
        targetProviderID: String
    ) throws -> Int {
        let databaseFiles = try stateDatabaseFiles(in: codexHome)
        guard !databaseFiles.isEmpty, !matchingThreadIDs.isEmpty else { return 0 }

        var updatedRows = 0
        for databaseFile in databaseFiles {
            updatedRows += try rewriteStateDatabase(
                at: databaseFile.url,
                matchingThreadIDs: matchingThreadIDs,
                targetProviderID: targetProviderID
            )
        }
        return updatedRows
    }

    private func verifyRewriteConsistency(
        in codexHome: STFolder,
        matchingThreadIDs: Set<String>,
        targetProviderID: String
    ) -> [String] {
        guard !matchingThreadIDs.isEmpty else { return [] }

        var failures: [String] = []
        let scannedFiles = CodexSessionScanner.scanFiles(codexHome: codexHome, includeArchived: true)
        for scannedFile in scannedFiles {
            guard let sessionMeta = CodexSessionScanner.readSessionMeta(from: scannedFile),
                  let threadID = sessionMeta.threadID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  matchingThreadIDs.contains(threadID)
            else {
                continue
            }

            let rolloutProvider = CodexSessionScanner.normalizedProviderID(sessionMeta.modelProvider) ?? defaultProviderID
            if rolloutProvider != targetProviderID {
                failures.append(
                    "rewrite verification: rollout \(scannedFile.relativePath) for thread \(threadID) still points to \(rolloutProvider), expected \(targetProviderID)"
                )
            }
        }

        do {
            for databaseFile in try stateDatabaseFiles(in: codexHome) {
                for row in try loadThreadRows(from: databaseFile.url) where matchingThreadIDs.contains(row.threadID) {
                    if row.modelProvider != targetProviderID {
                        failures.append(
                            "rewrite verification: state db \(databaseFile.attributes.name) for thread \(row.threadID) still points to \(row.modelProvider), expected \(targetProviderID)"
                        )
                    }
                }
            }
        } catch {
            failures.append("rewrite verification: \(error.localizedDescription)")
        }

        return failures
    }

    private func rewriteStateDatabases(
        in codexHome: STFolder,
        matchingProviderIDs: Set<String>,
        targetProviderID: String
    ) throws -> Int {
        let databaseFiles = try stateDatabaseFiles(in: codexHome)
        guard !databaseFiles.isEmpty, !matchingProviderIDs.isEmpty else { return 0 }

        var updatedRows = 0
        for databaseFile in databaseFiles {
            updatedRows += try rewriteStateDatabase(
                at: databaseFile.url,
                matchingProviderIDs: matchingProviderIDs,
                targetProviderID: targetProviderID
            )
        }
        return updatedRows
    }

    private func rewriteStateDatabase(
        at databaseURL: URL,
        matchingThreadIDs: Set<String>,
        targetProviderID: String
    ) throws -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(
                domain: "CodexSessionStore.SQLite",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex state database." : message]
            )
        }
        defer { sqlite3_close(db) }

        guard try sqliteTableExists(db: db, table: "threads") else { return 0 }

        let sortedThreadIDs = matchingThreadIDs.sorted()
        let placeholders = Array(repeating: "?", count: sortedThreadIDs.count).joined(separator: ", ")
        let sql = """
        UPDATE threads
        SET model_provider = ?
        WHERE id IN (\(placeholders))
          AND lower(model_provider) <> ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(
                domain: "CodexSessionStore.SQLite",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare Codex state update." : message]
            )
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, targetProviderID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        for (index, threadID) in sortedThreadIDs.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 2), threadID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        sqlite3_bind_text(
            statement,
            Int32(sortedThreadIDs.count + 2),
            targetProviderID,
            -1,
            unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        )

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(
                domain: "CodexSessionStore.SQLite",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Failed to update Codex thread providers." : message]
            )
        }
        return Int(sqlite3_changes(db))
    }

    private func rewriteStateDatabase(
        at databaseURL: URL,
        matchingProviderIDs: Set<String>,
        targetProviderID: String
    ) throws -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(
                domain: "CodexSessionStore.SQLite",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Failed to open Codex state database." : message]
            )
        }
        defer { sqlite3_close(db) }

        guard try sqliteTableExists(db: db, table: "threads") else { return 0 }

        let sortedProviderIDs = matchingProviderIDs.sorted()
        let placeholders = Array(repeating: "?", count: sortedProviderIDs.count).joined(separator: ", ")
        let sql = """
        UPDATE threads
        SET model_provider = ?
        WHERE lower(model_provider) IN (\(placeholders));
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(
                domain: "CodexSessionStore.SQLite",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Failed to prepare Codex state update." : message]
            )
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, targetProviderID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        for (index, providerID) in sortedProviderIDs.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 2), providerID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(
                domain: "CodexSessionStore.SQLite",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Failed to update Codex thread providers." : message]
            )
        }
        return Int(sqlite3_changes(db))
    }

    private func stateDatabaseFiles(in codexHome: STFolder) throws -> [STFile] {
        guard codexHome.isExists else { return [] }
        return try codexHome.files().filter { file in
            let name = file.attributes.name.lowercased()
            return name.hasPrefix("state") && name.hasSuffix(".sqlite")
        }
    }

    private func sqliteTableExists(db: OpaquePointer?, table: String) throws -> Bool {
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(
                domain: "CodexSessionStore.SQLite",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Failed to inspect SQLite tables." : message]
            )
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, table, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private static func parseISO8601(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return makeISO8601Formatter(fractionalSeconds: false).date(from: raw)
            ?? makeISO8601Formatter(fractionalSeconds: true).date(from: raw)
    }

    private static func fileModificationDate(path: String) -> Date? {
        do {
            return try URL(fileURLWithPath: path)
                .resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
        } catch {
            return nil
        }
    }

    private static func elapsedMilliseconds(since startedAt: CFAbsoluteTime) -> Int {
        Int(((CFAbsoluteTimeGetCurrent() - startedAt) * 1_000).rounded())
    }

    private static func emitRewritePhase(
        traceID: String,
        phase: String,
        status: String,
        extra: [String: Any] = [:]
    ) {
        var payload = extra
        payload["phase"] = phase
        payload["status"] = status
        emitPerformance(
            operation: "rewrite_phase",
            traceID: traceID,
            startedAt: CFAbsoluteTimeGetCurrent(),
            extra: payload
        )
    }

    private static func emitPerformance(
        operation: String,
        traceID: String,
        startedAt: CFAbsoluteTime,
        extra: [String: Any]
    ) {
        let elapsedMs = Int(((CFAbsoluteTimeGetCurrent() - startedAt) * 1_000).rounded())
        var payload = extra
        if payload["elapsed_ms"] == nil {
            payload["elapsed_ms"] = elapsedMs
        }
        payload["operation"] = operation
        payload["trace_id"] = traceID

        let details = payload.keys.sorted().compactMap { key -> String? in
            guard let value = payload[key] else { return nil }
            return "\(key)=\(value)"
        }.joined(separator: " ")
        logger.info("performance \(details, privacy: .public)")
        if ProcessInfo.processInfo.environment["NOLON_CODEX_SESSION_PERF_STDERR"] == "1" {
            fputs("[CodexSessionStore] performance \(details)\n", stderr)
        }
        NotificationCenter.default.post(
            name: performanceNotification,
            object: nil,
            userInfo: payload
        )
    }

    private static func sortSessions(_ lhs: CodexSessionRecord, _ rhs: CodexSessionRecord) -> Bool {
        let leftDate = lhs.updatedAt ?? .distantPast
        let rightDate = rhs.updatedAt ?? .distantPast
        if leftDate != rightDate {
            return leftDate > rightDate
        }
        return lhs.rolloutPath < rhs.rolloutPath
    }

    private static func mergeSortedSessions(
        existing: [CodexSessionRecord],
        incoming: [CodexSessionRecord]
    ) -> [CodexSessionRecord] {
        guard !existing.isEmpty else { return incoming }
        guard !incoming.isEmpty else { return existing }

        var merged: [CodexSessionRecord] = []
        merged.reserveCapacity(existing.count + incoming.count)

        var existingIndex = 0
        var incomingIndex = 0

        while existingIndex < existing.count, incomingIndex < incoming.count {
            let existingSession = existing[existingIndex]
            let incomingSession = incoming[incomingIndex]
            if sortSessions(existingSession, incomingSession) {
                merged.append(existingSession)
                existingIndex += 1
            } else {
                merged.append(incomingSession)
                incomingIndex += 1
            }
        }

        if existingIndex < existing.count {
            merged.append(contentsOf: existing[existingIndex...])
        }
        if incomingIndex < incoming.count {
            merged.append(contentsOf: incoming[incomingIndex...])
        }
        return merged
    }

    private static func isStateRow(_ lhs: StateThreadRow, newerThan rhs: StateThreadRow) -> Bool {
        let lhsDate = lhs.updatedAt ?? .distantPast
        let rhsDate = rhs.updatedAt ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        return (lhs.title ?? "") > (rhs.title ?? "")
    }

    private static func normalizedProviderID(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }
        return raw.lowercased()
    }

    private static func normalizedThreadIDs(_ rawValues: [String]) -> Set<String> {
        Set(
            rawValues.compactMap { rawValue in
                let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private static func extractQuotedValue(from line: String, key: String) -> String? {
        guard let separatorIndex = line.firstIndex(of: "=") else { return nil }
        let left = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard left == key else { return nil }
        let rawValue = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.first == "\"", rawValue.last == "\"", rawValue.count >= 2 else { return nil }
        return String(rawValue.dropFirst().dropLast())
    }

    private static func extractModelProviderSectionID(from line: String) -> String? {
        let prefix = "[model_providers."
        let suffix = "]"
        guard line.hasPrefix(prefix), line.hasSuffix(suffix), line.count > prefix.count + suffix.count else {
            return nil
        }
        let start = line.index(line.startIndex, offsetBy: prefix.count)
        let end = line.index(before: line.endIndex)
        return String(line[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeISO8601Formatter(fractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
