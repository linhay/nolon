import CryptoKit
import Foundation
import ProvidersShared
import SQLite3
import STFilePath

public enum CodexSessionCachedUsageLookupResult: Equatable, Sendable {
    case miss
    case hit(CodexSessionTokenTotals?)
}

enum CodexSessionUsageLoadSource: Equatable, Sendable {
    case cacheHit
    case deltaAppend
    case fullRebuild
    case fileMissing
}

struct CodexSessionUsageLoadResult: Equatable, Sendable {
    let sessionID: String?
    let totals: CodexSessionTokenTotals?
    let timeline: CodexSessionTimeline?
    let source: CodexSessionUsageLoadSource
}

struct CodexSessionUsageMinuteEntry: Equatable, Sendable {
    let codexHomePath: String
    let rolloutPath: String
    let sessionID: String?
    let minuteStartUnixMs: Int64
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let requestCount: Int
    let updatedAtUnixMs: Int64

    var minuteStartAt: Date {
        Date(timeIntervalSince1970: TimeInterval(minuteStartUnixMs) / 1_000)
    }
}

public struct CodexSessionProjectedMinuteEntry: Equatable, Sendable {
    public let minuteStartUnixMs: Int64
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let requestCount: Int

    public var minuteStartAt: Date {
        Date(timeIntervalSince1970: TimeInterval(minuteStartUnixMs) / 1_000)
    }

    public init(
        minuteStartUnixMs: Int64,
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        requestCount: Int = 0
    ) {
        self.minuteStartUnixMs = minuteStartUnixMs
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.requestCount = requestCount
    }
}

public struct CodexSessionProjectedUsage: Equatable, Sendable {
    public let entries: [CodexSessionProjectedMinuteEntry]
    public let updatedAt: Date
    public let sourceLabel: String

    public init(
        entries: [CodexSessionProjectedMinuteEntry],
        updatedAt: Date,
        sourceLabel: String
    ) {
        self.entries = entries
        self.updatedAt = updatedAt
        self.sourceLabel = sourceLabel
    }
}

public struct CodexSessionProjectedUsageSummary: Equatable, Sendable {
    public let totalTokens: Int
    public let requestCount: Int
    public let updatedAt: Date
    public let sourceLabel: String

    public init(
        totalTokens: Int,
        requestCount: Int = 0,
        updatedAt: Date,
        sourceLabel: String
    ) {
        self.totalTokens = totalTokens
        self.requestCount = requestCount
        self.updatedAt = updatedAt
        self.sourceLabel = sourceLabel
    }
}

struct CodexSessionProjectedBucketSnapshot: Equatable, Sendable {
    let buckets: [String: [Int]]
    let updatedAt: Date
    let sourceLabel: String
}

private struct CodexSessionLogicalMinuteKey: Hashable, Sendable {
    let logicalSessionID: String
    let minuteStartUnixMs: Int64
}

struct CodexSessionUsageIndexEntry: Equatable, Sendable {
    let codexHomePath: String
    let rolloutPath: String
    let absoluteRolloutPath: String
    let sessionID: String?
    let contentHash: String?
    let fileID: Int64?
    let modifiedAtUnixMs: Int64
    let sizeBytes: Int64
    let parsedBytes: Int64
    let lastModel: String?
    let totals: CodexSessionTokenTotals?
    let startedAtUnixMs: Int64?
    let lastActivityAtUnixMs: Int64?
    let updatedAtUnixMs: Int64
    let lastSeenAtUnixMs: Int64
    let lastRequestedAtUnixMs: Int64
    let isArchived: Bool

    var timeline: CodexSessionTimeline? {
        guard startedAtUnixMs != nil || lastActivityAtUnixMs != nil else { return nil }
        return .init(
            startedAt: startedAtUnixMs.map { Self.date(from: $0) },
            lastActivityAt: lastActivityAtUnixMs.map { Self.date(from: $0) }
        )
    }

    private static func date(from unixMilliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(unixMilliseconds) / 1_000)
    }
}

private struct CodexSessionUsageFileFingerprint: Equatable, Sendable {
    let absoluteRolloutPath: String
    let fileID: Int64?
    let modifiedAtUnixMs: Int64
    let sizeBytes: Int64
}

private struct CodexSessionUsageParseResult: Sendable {
    let sessionID: String?
    let lastModel: String?
    let totals: CodexSessionTokenTotals?
    let timeline: CodexSessionTimeline?
    let minuteBuckets: [Int64: CodexSessionTokenTotals]
    let parsedBytes: Int64
}

final class CodexSessionUsageIndex: @unchecked Sendable {
    private let fileManager: FileManager
    private let databaseURL: URL

    var databasePath: String {
        databaseURL.path
    }

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        let root: URL
        if let rootDirectory {
            root = rootDirectory
        } else {
            let appSupport = NolonHomeEnvironment.resolveApplicationSupportFolder(
                environment: ProcessInfo.processInfo.environment,
                fileManager: fileManager
            )
            root = appSupport
                .appendingPathComponent("Nolon", isDirectory: true)
                .appendingPathComponent("codex-sessions", isDirectory: true)
        }
        self.databaseURL = root.appendingPathComponent("usage-index-v1.sqlite", isDirectory: false)
    }

    func load(
        codexHome: URL,
        rolloutPath: String,
        isArchived: Bool = false
    ) throws -> CodexSessionUsageLoadResult {
        let resolvedRolloutURL = Self.resolveRolloutURL(codexHome: codexHome, rolloutPath: rolloutPath)
        guard fileManager.fileExists(atPath: resolvedRolloutURL.path) else {
            try deleteEntry(codexHomePath: codexHome.path, rolloutPath: rolloutPath)
            return .init(sessionID: nil, totals: nil, timeline: nil, source: .fileMissing)
        }

        let requestedAtUnixMs = Self.currentUnixMs()
        let cachedEntry = try loadEntry(codexHomePath: codexHome.path, rolloutPath: rolloutPath)
        let cachedMinuteEntriesExist = try hasMinuteEntries(
            codexHomePath: codexHome.path,
            rolloutPath: rolloutPath
        )
        let requiresRequestCountBackfill: Bool
        if cachedMinuteEntriesExist {
            requiresRequestCountBackfill = try hasRequestlessTokenUsageMinuteEntries(
                codexHomePath: codexHome.path,
                rolloutPath: rolloutPath
            )
        } else {
            requiresRequestCountBackfill = false
        }

        if isArchived,
           let cachedEntry,
           cachedEntry.isArchived,
           cachedEntry.contentHash != nil,
           !requiresRequestCountBackfill,
           cachedEntry.totals == nil || cachedMinuteEntriesExist {
            try upsert(
                Self.touch(
                    entry: cachedEntry,
                    requestedAtUnixMs: requestedAtUnixMs,
                    isArchived: true
                )
            )
            return .init(
                sessionID: cachedEntry.sessionID,
                totals: cachedEntry.totals,
                timeline: cachedEntry.timeline,
                source: .cacheHit
            )
        }

        let fingerprint = try Self.fileFingerprint(
            fileManager: fileManager,
            url: resolvedRolloutURL
        )

        let requiresArchivedRepair = isArchived && cachedEntry.map {
            !$0.isArchived || $0.contentHash == nil
        } == true

        if let cachedEntry,
           !requiresArchivedRepair,
           !requiresRequestCountBackfill,
           Self.matchesCache(entry: cachedEntry, fingerprint: fingerprint),
           cachedEntry.totals == nil || cachedMinuteEntriesExist {
            try upsert(
                Self.touch(
                    entry: cachedEntry,
                    requestedAtUnixMs: requestedAtUnixMs,
                    isArchived: cachedEntry.isArchived || isArchived
                )
            )
            return .init(
                sessionID: cachedEntry.sessionID,
                totals: cachedEntry.totals,
                timeline: cachedEntry.timeline,
                source: .cacheHit
            )
        }

        let parseResult: CodexSessionUsageParseResult
        let source: CodexSessionUsageLoadSource
        let isDerivedRollout = CodexSessionScanner.readSessionMeta(
            from: STFile(resolvedRolloutURL)
        )?.forkedFromID != nil

        if let cachedEntry,
           !requiresRequestCountBackfill,
           !isDerivedRollout,
           Self.canUseAppendDelta(entry: cachedEntry, fingerprint: fingerprint) {
            do {
                parseResult = try Self.parseUsageFile(
                    at: resolvedRolloutURL,
                    fromOffset: cachedEntry.parsedBytes,
                    currentModel: cachedEntry.lastModel,
                    currentTotals: cachedEntry.totals,
                    currentTimeline: cachedEntry.timeline,
                    sessionID: cachedEntry.sessionID,
                    ignoresInitialDerivedBaseline: false
                )
                source = .deltaAppend
            } catch {
                parseResult = try Self.parseUsageFile(
                    at: resolvedRolloutURL,
                    fromOffset: 0,
                    currentModel: nil,
                    currentTotals: nil,
                    currentTimeline: nil,
                    sessionID: nil,
                    ignoresInitialDerivedBaseline: isDerivedRollout
                )
                source = .fullRebuild
            }
        } else {
            parseResult = try Self.parseUsageFile(
                at: resolvedRolloutURL,
                fromOffset: 0,
                currentModel: nil,
                currentTotals: nil,
                currentTimeline: nil,
                sessionID: nil,
                ignoresInitialDerivedBaseline: isDerivedRollout
            )
            source = .fullRebuild
        }

        let effectiveTimeline = parseResult.timeline ?? Self.fallbackTimeline(from: fingerprint)
        let updatedAtUnixMs = requestedAtUnixMs
        let contentHash = if isArchived {
            try Self.contentHash(fileURL: resolvedRolloutURL)
        } else {
            cachedEntry?.contentHash
        }

        switch source {
        case .cacheHit:
            break
        case .deltaAppend:
            try upsertMinuteEntries(
                codexHomePath: codexHome.path,
                rolloutPath: rolloutPath,
                sessionID: parseResult.sessionID,
                minuteBuckets: parseResult.minuteBuckets,
                updatedAtUnixMs: updatedAtUnixMs
            )
        case .fullRebuild:
            try replaceMinuteEntries(
                codexHomePath: codexHome.path,
                rolloutPath: rolloutPath,
                sessionID: parseResult.sessionID,
                minuteBuckets: parseResult.minuteBuckets,
                updatedAtUnixMs: updatedAtUnixMs
            )
        case .fileMissing:
            break
        }

        if parseResult.sessionID != nil {
            try updateMinuteEntrySessionID(
                codexHomePath: codexHome.path,
                rolloutPath: rolloutPath,
                sessionID: parseResult.sessionID
            )
        }

        try upsert(
            .init(
                codexHomePath: codexHome.path,
                rolloutPath: rolloutPath,
                absoluteRolloutPath: resolvedRolloutURL.path,
                sessionID: parseResult.sessionID,
                contentHash: contentHash,
                fileID: fingerprint.fileID,
                modifiedAtUnixMs: fingerprint.modifiedAtUnixMs,
                sizeBytes: fingerprint.sizeBytes,
                parsedBytes: parseResult.parsedBytes,
                lastModel: parseResult.lastModel,
                totals: parseResult.totals,
                startedAtUnixMs: Self.unixMilliseconds(effectiveTimeline?.startedAt),
                lastActivityAtUnixMs: Self.unixMilliseconds(effectiveTimeline?.lastActivityAt),
                updatedAtUnixMs: updatedAtUnixMs,
                lastSeenAtUnixMs: requestedAtUnixMs,
                lastRequestedAtUnixMs: requestedAtUnixMs,
                isArchived: isArchived
            )
        )

        return .init(
            sessionID: parseResult.sessionID,
            totals: parseResult.totals,
            timeline: effectiveTimeline,
            source: source
        )
    }

    func loadEntry(
        codexHomePath: String,
        rolloutPath: String
    ) throws -> CodexSessionUsageIndexEntry? {
        try withDatabase { db in
            let sql = """
            SELECT
                codex_home_path,
                rollout_path,
                absolute_rollout_path,
                session_id,
                content_hash,
                file_id,
                mtime_unix_ms,
                size_bytes,
                parsed_bytes,
                last_model,
                input_tokens,
                cached_input_tokens,
                output_tokens,
                request_count,
                started_at_unix_ms,
                last_activity_at_unix_ms,
                updated_at_unix_ms,
                last_seen_at_unix_ms,
                last_requested_at_unix_ms,
                is_archived
            FROM usage_entries
            WHERE codex_home_path = ? AND rollout_path = ?;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 2, fallback: "Failed to prepare usage entry read.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }

            return Self.makeEntry(statement: statement)
        }
    }

    func loadMinuteEntries(
        codexHomePath: String,
        rolloutPath: String
    ) throws -> [CodexSessionUsageMinuteEntry] {
        try withDatabase { db in
            let sql = """
            SELECT
                codex_home_path,
                rollout_path,
                session_id,
                minute_start_unix_ms,
                input_tokens,
                cached_input_tokens,
                output_tokens,
                request_count,
                updated_at_unix_ms
            FROM session_usage_minutes
            WHERE codex_home_path = ? AND rollout_path = ?
            ORDER BY minute_start_unix_ms ASC;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 9, fallback: "Failed to prepare minute entry read.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            var rows: [CodexSessionUsageMinuteEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                rows.append(Self.makeMinuteEntry(statement: statement))
            }
            return rows
        }
    }

    func loadProjectedUsage(
        codexHomePath: String,
        rangeStartUnixMs: Int64? = nil,
        rangeEndUnixMs: Int64? = nil
    ) throws -> CodexSessionProjectedUsage {
        let entries = try loadEntries(codexHomePath: codexHomePath)
        guard !entries.isEmpty else {
            return .init(entries: [], updatedAt: Date(), sourceLabel: "global local usage")
        }

        var projectedEntries: [CodexSessionProjectedMinuteEntry] = []
        var latestUpdatedAtUnixMs = entries.map(\.updatedAtUnixMs).max() ?? 0

        try enumerateProjectedMinuteTotals(
            codexHomePath: codexHomePath,
            rangeStartUnixMs: rangeStartUnixMs,
            rangeEndUnixMs: rangeEndUnixMs
        ) { minuteStartUnixMs, totals, updatedAtUnixMs in
            latestUpdatedAtUnixMs = max(latestUpdatedAtUnixMs, updatedAtUnixMs)
            projectedEntries.append(
                CodexSessionProjectedMinuteEntry(
                minuteStartUnixMs: minuteStartUnixMs,
                inputTokens: totals.inputTokens,
                cachedInputTokens: totals.cachedInputTokens,
                outputTokens: totals.outputTokens,
                requestCount: totals.requestCount
            )
            )
        }

        return .init(
            entries: projectedEntries,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(latestUpdatedAtUnixMs) / 1_000),
            sourceLabel: "global local usage"
        )
    }

    func loadProjectedUsageSummary(
        codexHomePath: String,
        rangeStartUnixMs: Int64? = nil,
        rangeEndUnixMs: Int64? = nil
    ) throws -> CodexSessionProjectedUsageSummary? {
        let entries = try loadEntries(codexHomePath: codexHomePath)
        guard !entries.isEmpty else { return nil }

        var totalTokens = 0
        var requestCount = 0
        var latestUpdatedAtUnixMs = entries.map(\.updatedAtUnixMs).max() ?? 0
        var hasProjectedMinute = false

        try enumerateProjectedMinuteTotals(
            codexHomePath: codexHomePath,
            rangeStartUnixMs: rangeStartUnixMs,
            rangeEndUnixMs: rangeEndUnixMs
        ) { _, totals, updatedAtUnixMs in
            hasProjectedMinute = true
            totalTokens += max(0, totals.inputTokens + totals.outputTokens)
            requestCount += max(0, totals.requestCount)
            latestUpdatedAtUnixMs = max(latestUpdatedAtUnixMs, updatedAtUnixMs)
        }

        guard hasProjectedMinute else { return nil }
        return .init(
            totalTokens: totalTokens,
            requestCount: requestCount,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(latestUpdatedAtUnixMs) / 1_000),
            sourceLabel: "global local usage"
        )
    }

    func loadProjectedQuarterHours(
        codexHomePath: String,
        rangeStartUnixMs: Int64? = nil,
        rangeEndUnixMs: Int64? = nil,
        timezone: TimeZone
    ) throws -> CodexSessionProjectedBucketSnapshot? {
        let entries = try loadEntries(codexHomePath: codexHomePath)
        guard !entries.isEmpty else { return nil }

        var quarterHours: [String: [Int]] = [:]
        var latestUpdatedAtUnixMs = entries.map(\.updatedAtUnixMs).max() ?? 0

        try enumerateProjectedMinuteTotals(
            codexHomePath: codexHomePath,
            rangeStartUnixMs: rangeStartUnixMs,
            rangeEndUnixMs: rangeEndUnixMs
        ) { minuteStartUnixMs, totals, updatedAtUnixMs in
            let bucketKey = Self.quarterHourKey(
                minuteStartUnixMs: minuteStartUnixMs,
                timezone: timezone
            )
            var packed = quarterHours[bucketKey] ?? [0, 0, 0, 0]
            packed[0] += totals.inputTokens
            packed[1] += totals.cachedInputTokens
            packed[2] += totals.outputTokens
            packed[3] += totals.requestCount
            quarterHours[bucketKey] = packed
            latestUpdatedAtUnixMs = max(latestUpdatedAtUnixMs, updatedAtUnixMs)
        }

        return .init(
            buckets: quarterHours,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(latestUpdatedAtUnixMs) / 1_000),
            sourceLabel: "global local usage"
        )
    }

    func loadLogicalSessionUsage(
        codexHomePath: String,
        sessionID: String?,
        rolloutPaths: Set<String>
    ) throws -> CodexSessionTokenTotals? {
        let normalizedSessionID = Self.normalizedSessionID(sessionID)
        if !rolloutPaths.isEmpty,
           let totals = try loadAggregatedLogicalSessionUsage(
            codexHomePath: codexHomePath,
            rolloutPaths: rolloutPaths
           ) {
            return totals
        }

        guard let normalizedSessionID else {
            return nil
        }
        return try loadAggregatedLogicalSessionUsage(
            codexHomePath: codexHomePath,
            sessionID: normalizedSessionID
        )
    }

    func purgeEntries(
        codexHomePath: String,
        keepingRolloutPaths: Set<String>
    ) throws {
        let existingRolloutPaths = try loadEntries(codexHomePath: codexHomePath).map(\.rolloutPath)
        for rolloutPath in existingRolloutPaths where !keepingRolloutPaths.contains(rolloutPath) {
            try deleteEntry(codexHomePath: codexHomePath, rolloutPath: rolloutPath)
        }
    }

    private func upsert(_ entry: CodexSessionUsageIndexEntry) throws {
        try withDatabase { db in
            let sql = """
            INSERT INTO usage_entries (
                codex_home_path,
                rollout_path,
                absolute_rollout_path,
                session_id,
                content_hash,
                file_id,
                mtime_unix_ms,
                size_bytes,
                parsed_bytes,
                last_model,
                input_tokens,
                cached_input_tokens,
                output_tokens,
                request_count,
                started_at_unix_ms,
                last_activity_at_unix_ms,
                updated_at_unix_ms,
                last_seen_at_unix_ms,
                last_requested_at_unix_ms,
                is_archived
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(codex_home_path, rollout_path) DO UPDATE SET
                absolute_rollout_path = excluded.absolute_rollout_path,
                session_id = excluded.session_id,
                content_hash = excluded.content_hash,
                file_id = excluded.file_id,
                mtime_unix_ms = excluded.mtime_unix_ms,
                size_bytes = excluded.size_bytes,
                parsed_bytes = excluded.parsed_bytes,
                last_model = excluded.last_model,
                input_tokens = excluded.input_tokens,
                cached_input_tokens = excluded.cached_input_tokens,
                output_tokens = excluded.output_tokens,
                request_count = excluded.request_count,
                started_at_unix_ms = excluded.started_at_unix_ms,
                last_activity_at_unix_ms = excluded.last_activity_at_unix_ms,
                updated_at_unix_ms = excluded.updated_at_unix_ms,
                last_seen_at_unix_ms = excluded.last_seen_at_unix_ms,
                last_requested_at_unix_ms = excluded.last_requested_at_unix_ms,
                is_archived = excluded.is_archived;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 3, fallback: "Failed to prepare usage entry upsert.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, entry.codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, entry.rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 3, entry.absoluteRolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            Self.bindOptionalText(entry.sessionID, to: statement, at: 4)
            Self.bindOptionalText(entry.contentHash, to: statement, at: 5)
            Self.bindOptionalInt64(entry.fileID, to: statement, at: 6)
            sqlite3_bind_int64(statement, 7, entry.modifiedAtUnixMs)
            sqlite3_bind_int64(statement, 8, entry.sizeBytes)
            sqlite3_bind_int64(statement, 9, entry.parsedBytes)
            Self.bindOptionalText(entry.lastModel, to: statement, at: 10)
            Self.bindOptionalInt64(entry.totals.map { Int64($0.inputTokens) }, to: statement, at: 11)
            Self.bindOptionalInt64(entry.totals.map { Int64($0.cachedInputTokens) }, to: statement, at: 12)
            Self.bindOptionalInt64(entry.totals.map { Int64($0.outputTokens) }, to: statement, at: 13)
            Self.bindOptionalInt64(entry.totals.map { Int64($0.requestCount) }, to: statement, at: 14)
            Self.bindOptionalInt64(entry.startedAtUnixMs, to: statement, at: 15)
            Self.bindOptionalInt64(entry.lastActivityAtUnixMs, to: statement, at: 16)
            sqlite3_bind_int64(statement, 17, entry.updatedAtUnixMs)
            sqlite3_bind_int64(statement, 18, entry.lastSeenAtUnixMs)
            sqlite3_bind_int64(statement, 19, entry.lastRequestedAtUnixMs)
            sqlite3_bind_int(statement, 20, entry.isArchived ? 1 : 0)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.sqliteError(db: db, code: 4, fallback: "Failed to write usage entry.")
            }
        }
    }

    private func deleteEntry(codexHomePath: String, rolloutPath: String) throws {
        try withDatabase { db in
            try deleteMinuteEntries(
                db: db,
                codexHomePath: codexHomePath,
                rolloutPath: rolloutPath
            )

            let sql = "DELETE FROM usage_entries WHERE codex_home_path = ? AND rollout_path = ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 5, fallback: "Failed to prepare usage entry delete.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.sqliteError(db: db, code: 6, fallback: "Failed to delete usage entry.")
            }
        }
    }

    private func withDatabase<T>(_ body: (OpaquePointer?) throws -> T) throws -> T {
        let directoryURL = databaseURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var db: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Failed to open usage index."
            sqlite3_close(db)
            throw NSError(
                domain: "CodexSessionUsageIndex.SQLite",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, 2_000)
        _ = sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        _ = sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
        _ = sqlite3_exec(
            db,
            """
            CREATE TABLE IF NOT EXISTS usage_entries (
                codex_home_path TEXT NOT NULL,
                rollout_path TEXT NOT NULL,
                absolute_rollout_path TEXT NOT NULL,
                session_id TEXT,
                content_hash TEXT,
                file_id INTEGER,
                mtime_unix_ms INTEGER NOT NULL,
                size_bytes INTEGER NOT NULL,
                parsed_bytes INTEGER NOT NULL,
                last_model TEXT,
                input_tokens INTEGER,
                cached_input_tokens INTEGER,
                output_tokens INTEGER,
                request_count INTEGER,
                started_at_unix_ms INTEGER,
                last_activity_at_unix_ms INTEGER,
                updated_at_unix_ms INTEGER NOT NULL,
                last_seen_at_unix_ms INTEGER NOT NULL DEFAULT 0,
                last_requested_at_unix_ms INTEGER NOT NULL DEFAULT 0,
                is_archived INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (codex_home_path, rollout_path)
            );
            CREATE INDEX IF NOT EXISTS usage_entries_session_id_idx
            ON usage_entries (codex_home_path, session_id);
            CREATE TABLE IF NOT EXISTS session_usage_minutes (
                codex_home_path TEXT NOT NULL,
                rollout_path TEXT NOT NULL,
                session_id TEXT,
                minute_start_unix_ms INTEGER NOT NULL,
                input_tokens INTEGER NOT NULL,
                cached_input_tokens INTEGER NOT NULL,
                output_tokens INTEGER NOT NULL,
                request_count INTEGER NOT NULL DEFAULT 0,
                updated_at_unix_ms INTEGER NOT NULL,
                PRIMARY KEY (codex_home_path, rollout_path, minute_start_unix_ms)
            );
            CREATE INDEX IF NOT EXISTS session_usage_minutes_session_idx
            ON session_usage_minutes (codex_home_path, session_id, minute_start_unix_ms);
            """,
            nil,
            nil,
            nil
        )
        try ensureColumnIfNeeded(
            db: db,
            table: "usage_entries",
            column: "request_count",
            definition: "INTEGER"
        )
        try ensureColumnIfNeeded(
            db: db,
            table: "session_usage_minutes",
            column: "request_count",
            definition: "INTEGER NOT NULL DEFAULT 0"
        )
        try ensureColumnIfNeeded(
            db: db,
            table: "usage_entries",
            column: "started_at_unix_ms",
            definition: "INTEGER"
        )
        try ensureColumnIfNeeded(
            db: db,
            table: "usage_entries",
            column: "last_activity_at_unix_ms",
            definition: "INTEGER"
        )
        try ensureColumnIfNeeded(
            db: db,
            table: "usage_entries",
            column: "content_hash",
            definition: "TEXT"
        )
        try ensureColumnIfNeeded(
            db: db,
            table: "usage_entries",
            column: "last_seen_at_unix_ms",
            definition: "INTEGER NOT NULL DEFAULT 0"
        )
        try ensureColumnIfNeeded(
            db: db,
            table: "usage_entries",
            column: "last_requested_at_unix_ms",
            definition: "INTEGER NOT NULL DEFAULT 0"
        )
        try ensureColumnIfNeeded(
            db: db,
            table: "usage_entries",
            column: "is_archived",
            definition: "INTEGER NOT NULL DEFAULT 0"
        )

        return try body(db)
    }

    private static func makeEntry(statement: OpaquePointer?) -> CodexSessionUsageIndexEntry {
        let inputTokens = sqliteInt(statement, column: 10)
        let cachedInputTokens = sqliteInt(statement, column: 11)
        let outputTokens = sqliteInt(statement, column: 12)
        let requestCount = sqliteInt(statement, column: 13)
        let totals: CodexSessionTokenTotals?
        if let inputTokens, let cachedInputTokens, let outputTokens {
            totals = .init(
                inputTokens: inputTokens,
                cachedInputTokens: cachedInputTokens,
                outputTokens: outputTokens,
                requestCount: requestCount ?? 0
            )
        } else {
            totals = nil
        }

        return .init(
            codexHomePath: sqliteText(statement, column: 0) ?? "",
            rolloutPath: sqliteText(statement, column: 1) ?? "",
            absoluteRolloutPath: sqliteText(statement, column: 2) ?? "",
            sessionID: sqliteText(statement, column: 3),
            contentHash: sqliteText(statement, column: 4),
            fileID: sqliteInt64(statement, column: 5),
            modifiedAtUnixMs: sqliteInt64(statement, column: 6) ?? 0,
            sizeBytes: sqliteInt64(statement, column: 7) ?? 0,
            parsedBytes: sqliteInt64(statement, column: 8) ?? 0,
            lastModel: sqliteText(statement, column: 9),
            totals: totals,
            startedAtUnixMs: sqliteInt64(statement, column: 14),
            lastActivityAtUnixMs: sqliteInt64(statement, column: 15),
            updatedAtUnixMs: sqliteInt64(statement, column: 16) ?? 0,
            lastSeenAtUnixMs: sqliteInt64(statement, column: 17) ?? 0,
            lastRequestedAtUnixMs: sqliteInt64(statement, column: 18) ?? 0,
            isArchived: sqliteInt(statement, column: 19) != 0
        )
    }

    private static func makeMinuteEntry(statement: OpaquePointer?) -> CodexSessionUsageMinuteEntry {
        .init(
            codexHomePath: sqliteText(statement, column: 0) ?? "",
            rolloutPath: sqliteText(statement, column: 1) ?? "",
            sessionID: sqliteText(statement, column: 2),
            minuteStartUnixMs: sqliteInt64(statement, column: 3) ?? 0,
            inputTokens: sqliteInt(statement, column: 4) ?? 0,
            cachedInputTokens: sqliteInt(statement, column: 5) ?? 0,
            outputTokens: sqliteInt(statement, column: 6) ?? 0,
            requestCount: sqliteInt(statement, column: 7) ?? 0,
            updatedAtUnixMs: sqliteInt64(statement, column: 8) ?? 0
        )
    }

    private static func resolveRolloutURL(codexHome: URL, rolloutPath: String) -> URL {
        if rolloutPath.hasPrefix("/") {
            return URL(fileURLWithPath: rolloutPath)
        }
        return codexHome.appendingPathComponent(rolloutPath)
    }

    private static func fileFingerprint(
        fileManager: FileManager,
        url: URL
    ) throws -> CodexSessionUsageFileFingerprint {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let modifiedAt = (attributes[.modificationDate] as? Date) ?? .distantPast
        let sizeBytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let fileID = (attributes[.systemFileNumber] as? NSNumber)?.int64Value
        return .init(
            absoluteRolloutPath: url.path,
            fileID: fileID,
            modifiedAtUnixMs: Int64((modifiedAt.timeIntervalSince1970 * 1_000.0).rounded()),
            sizeBytes: sizeBytes
        )
    }

    private static func contentHash(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty {
                break
            }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func touch(
        entry: CodexSessionUsageIndexEntry,
        requestedAtUnixMs: Int64,
        isArchived: Bool
    ) -> CodexSessionUsageIndexEntry {
        .init(
            codexHomePath: entry.codexHomePath,
            rolloutPath: entry.rolloutPath,
            absoluteRolloutPath: entry.absoluteRolloutPath,
            sessionID: entry.sessionID,
            contentHash: entry.contentHash,
            fileID: entry.fileID,
            modifiedAtUnixMs: entry.modifiedAtUnixMs,
            sizeBytes: entry.sizeBytes,
            parsedBytes: entry.parsedBytes,
            lastModel: entry.lastModel,
            totals: entry.totals,
            startedAtUnixMs: entry.startedAtUnixMs,
            lastActivityAtUnixMs: entry.lastActivityAtUnixMs,
            updatedAtUnixMs: entry.updatedAtUnixMs,
            lastSeenAtUnixMs: requestedAtUnixMs,
            lastRequestedAtUnixMs: requestedAtUnixMs,
            isArchived: isArchived
        )
    }

    private static func matchesCache(
        entry: CodexSessionUsageIndexEntry,
        fingerprint: CodexSessionUsageFileFingerprint
    ) -> Bool {
        entry.absoluteRolloutPath == fingerprint.absoluteRolloutPath
            && entry.fileID == fingerprint.fileID
            && entry.modifiedAtUnixMs == fingerprint.modifiedAtUnixMs
            && entry.sizeBytes == fingerprint.sizeBytes
    }

    private static func canUseAppendDelta(
        entry: CodexSessionUsageIndexEntry,
        fingerprint: CodexSessionUsageFileFingerprint
    ) -> Bool {
        guard entry.absoluteRolloutPath == fingerprint.absoluteRolloutPath else { return false }
        guard entry.fileID == fingerprint.fileID else { return false }
        guard fingerprint.sizeBytes >= entry.sizeBytes else { return false }
        guard entry.parsedBytes == entry.sizeBytes else { return false }
        guard fingerprint.sizeBytes > entry.sizeBytes else { return false }
        guard fingerprint.modifiedAtUnixMs >= entry.modifiedAtUnixMs else { return false }
        return true
    }

    private static func parseUsageFile(
        at url: URL,
        fromOffset: Int64,
        currentModel: String?,
        currentTotals: CodexSessionTokenTotals?,
        currentTimeline: CodexSessionTimeline?,
        sessionID: String?,
        ignoresInitialDerivedBaseline: Bool
    ) throws -> CodexSessionUsageParseResult {
        var nextSessionID = sessionID
        var nextModel = currentModel
        var nextTotals = currentTotals
        var rawTotals = currentTotals
        var startedAt = currentTimeline?.startedAt
        var lastActivityAt = currentTimeline?.lastActivityAt
        var minuteBuckets: [Int64: CodexSessionTokenTotals] = [:]
        var ignoredDerivedBaseline: CodexSessionTokenTotals?

        let parsedBytes = try CodexRolloutLineReader.readLines(at: url, fromOffset: fromOffset) { lineData in
            let adjustedTotalsBeforeLine = nextTotals
            let rawTotalsBeforeLine = rawTotals
            let reduction = CodexSessionEventParser.reduceUsageLine(
                data: lineData,
                currentModel: nextModel,
                previousTotals: rawTotals
            )
            if let updatedSessionID = reduction?.sessionID {
                nextSessionID = updatedSessionID
            }
            if let updatedModel = reduction?.updatedModel {
                nextModel = updatedModel
            }
            if let updatedTotals = reduction?.updatedTotals {
                rawTotals = updatedTotals
            }

            let ignoresBaselineForLine: Bool
            if ignoresInitialDerivedBaseline,
               ignoredDerivedBaseline == nil,
               rawTotalsBeforeLine == nil,
               let updatedTotals = reduction?.updatedTotals,
               let tokenDelta = reduction?.tokenDelta,
               Self.matches(delta: tokenDelta, totals: updatedTotals) {
                ignoredDerivedBaseline = Self.subtractTotals(
                    updatedTotals,
                    adjustedTotalsBeforeLine
                )
                ignoresBaselineForLine = true
            } else {
                ignoresBaselineForLine = false
            }

            if let tokenDelta = reduction?.tokenDelta,
               !ignoresBaselineForLine,
               let timestamp = Self.parseISO8601(tokenDelta.timestamp) {
                let minuteStartUnixMs = Self.minuteStartUnixMilliseconds(for: timestamp)
                let current = minuteBuckets[minuteStartUnixMs]
                minuteBuckets[minuteStartUnixMs] = .init(
                    inputTokens: (current?.inputTokens ?? 0) + tokenDelta.inputTokens,
                    cachedInputTokens: (current?.cachedInputTokens ?? 0) + tokenDelta.cachedInputTokens,
                    outputTokens: (current?.outputTokens ?? 0) + tokenDelta.outputTokens,
                    requestCount: (current?.requestCount ?? 0) + tokenDelta.requestCount
                )
                nextTotals = Self.addDelta(tokenDelta, to: nextTotals)
            }
            if let updatedTotals = reduction?.updatedTotals {
                nextTotals = if let ignoredDerivedBaseline {
                    Self.subtractTotals(updatedTotals, ignoredDerivedBaseline)
                } else {
                    updatedTotals
                }
            }
            if let rawTimestamp = CodexSessionEventParser.fastTopLevelTimestamp(data: lineData),
               let timestamp = Self.parseISO8601(rawTimestamp) {
                if startedAt == nil {
                    startedAt = timestamp
                }
                lastActivityAt = timestamp
            }
        }

        return .init(
            sessionID: nextSessionID,
            lastModel: nextModel,
            totals: nextTotals,
            timeline: (startedAt != nil || lastActivityAt != nil)
                ? .init(startedAt: startedAt, lastActivityAt: lastActivityAt)
                : nil,
            minuteBuckets: minuteBuckets,
            parsedBytes: parsedBytes
        )
    }

    private static func matches(
        delta: CodexSessionTokenDelta,
        totals: CodexSessionTokenTotals
    ) -> Bool {
        delta.inputTokens == totals.inputTokens
            && delta.cachedInputTokens == totals.cachedInputTokens
            && delta.outputTokens == totals.outputTokens
    }

    private static func subtractTotals(
        _ lhs: CodexSessionTokenTotals,
        _ rhs: CodexSessionTokenTotals?
    ) -> CodexSessionTokenTotals {
        .init(
            inputTokens: max(0, lhs.inputTokens - (rhs?.inputTokens ?? 0)),
            cachedInputTokens: max(0, lhs.cachedInputTokens - (rhs?.cachedInputTokens ?? 0)),
            outputTokens: max(0, lhs.outputTokens - (rhs?.outputTokens ?? 0)),
            requestCount: max(0, lhs.requestCount - (rhs?.requestCount ?? 0))
        )
    }

    private static func addDelta(
        _ delta: CodexSessionTokenDelta,
        to totals: CodexSessionTokenTotals?
    ) -> CodexSessionTokenTotals {
        .init(
            inputTokens: (totals?.inputTokens ?? 0) + delta.inputTokens,
            cachedInputTokens: (totals?.cachedInputTokens ?? 0) + delta.cachedInputTokens,
            outputTokens: (totals?.outputTokens ?? 0) + delta.outputTokens,
            requestCount: (totals?.requestCount ?? 0) + delta.requestCount
        )
    }

    private static func quarterHourKey(
        minuteStartUnixMs: Int64,
        timezone: TimeZone
    ) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(minuteStartUnixMs) / 1_000)
        let calendar = calendar(timezone: timezone)
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let flooredMinute = (minute / 15) * 15
        return String(format: "%02d:%02d", hour, flooredMinute)
    }

    private static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }

    func loadEntries(codexHomePath: String) throws -> [CodexSessionUsageIndexEntry] {
        try withDatabase { db in
            let sql = """
            SELECT
                codex_home_path,
                rollout_path,
                absolute_rollout_path,
                session_id,
                content_hash,
                file_id,
                mtime_unix_ms,
                size_bytes,
                parsed_bytes,
                last_model,
                input_tokens,
                cached_input_tokens,
                output_tokens,
                request_count,
                started_at_unix_ms,
                last_activity_at_unix_ms,
                updated_at_unix_ms,
                last_seen_at_unix_ms,
                last_requested_at_unix_ms,
                is_archived
            FROM usage_entries
            WHERE codex_home_path = ?;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 10, fallback: "Failed to prepare usage entry scan.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            var rows: [CodexSessionUsageIndexEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                rows.append(Self.makeEntry(statement: statement))
            }
            return rows
        }
    }

    private func loadMinuteEntries(
        codexHomePath: String,
        rangeStartUnixMs: Int64?,
        rangeEndUnixMs: Int64?
    ) throws -> [CodexSessionUsageMinuteEntry] {
        try withDatabase { db in
            var sql = """
            SELECT
                codex_home_path,
                rollout_path,
                session_id,
                minute_start_unix_ms,
                input_tokens,
                cached_input_tokens,
                output_tokens,
                request_count,
                updated_at_unix_ms
            FROM session_usage_minutes
            WHERE codex_home_path = ?
            """
            if rangeStartUnixMs != nil {
                sql += " AND minute_start_unix_ms >= ?"
            }
            if rangeEndUnixMs != nil {
                sql += " AND minute_start_unix_ms < ?"
            }
            sql += " ORDER BY minute_start_unix_ms ASC;"

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 11, fallback: "Failed to prepare minute scan.")
            }
            defer { sqlite3_finalize(statement) }

            var bindIndex: Int32 = 1
            sqlite3_bind_text(statement, bindIndex, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            bindIndex += 1
            if let rangeStartUnixMs {
                sqlite3_bind_int64(statement, bindIndex, rangeStartUnixMs)
                bindIndex += 1
            }
            if let rangeEndUnixMs {
                sqlite3_bind_int64(statement, bindIndex, rangeEndUnixMs)
            }

            var rows: [CodexSessionUsageMinuteEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                rows.append(Self.makeMinuteEntry(statement: statement))
            }
            return rows
        }
    }

    private func hasMinuteEntries(
        codexHomePath: String,
        rolloutPath: String
    ) throws -> Bool {
        try withDatabase { db in
            let sql = """
            SELECT 1
            FROM session_usage_minutes
            WHERE codex_home_path = ? AND rollout_path = ?
            LIMIT 1;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 20, fallback: "Failed to inspect minute entry presence.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            return sqlite3_step(statement) == SQLITE_ROW
        }
    }

    private func hasRequestlessTokenUsageMinuteEntries(
        codexHomePath: String,
        rolloutPath: String
    ) throws -> Bool {
        try withDatabase { db in
            let sql = """
            SELECT 1
            FROM session_usage_minutes
            WHERE codex_home_path = ?
              AND rollout_path = ?
              AND (input_tokens > 0 OR cached_input_tokens > 0 OR output_tokens > 0)
              AND IFNULL(request_count, 0) <= 0
            LIMIT 1;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 24, fallback: "Failed to inspect minute request backfill state.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            return sqlite3_step(statement) == SQLITE_ROW
        }
    }

    private func loadMinuteEntries(
        codexHomePath: String,
        sessionID: String
    ) throws -> [CodexSessionUsageMinuteEntry] {
        try withDatabase { db in
            let sql = """
            SELECT
                codex_home_path,
                rollout_path,
                session_id,
                minute_start_unix_ms,
                input_tokens,
                cached_input_tokens,
                output_tokens,
                request_count,
                updated_at_unix_ms
            FROM session_usage_minutes
            WHERE codex_home_path = ? AND session_id = ?
            ORDER BY minute_start_unix_ms ASC;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 18, fallback: "Failed to prepare minute session scan.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, sessionID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            var rows: [CodexSessionUsageMinuteEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                rows.append(Self.makeMinuteEntry(statement: statement))
            }
            return rows
        }
    }

    private func enumerateProjectedMinuteTotals(
        codexHomePath: String,
        rangeStartUnixMs: Int64?,
        rangeEndUnixMs: Int64?,
        handleRow: (_ minuteStartUnixMs: Int64, _ totals: CodexSessionTokenTotals, _ updatedAtUnixMs: Int64) -> Void
    ) throws {
        try withDatabase { db in
            var sql = """
            SELECT
                minute_start_unix_ms,
                SUM(input_tokens) AS input_tokens,
                SUM(cached_input_tokens) AS cached_input_tokens,
                SUM(output_tokens) AS output_tokens,
                SUM(request_count) AS request_count,
                MAX(updated_at_unix_ms) AS updated_at_unix_ms
            FROM (
                SELECT
                    CASE
                        WHEN session_id IS NULL OR TRIM(session_id) = '' THEN 'rollout:' || rollout_path
                        ELSE TRIM(session_id)
                    END AS logical_session_id,
                    minute_start_unix_ms,
                    MAX(input_tokens) AS input_tokens,
                    MAX(cached_input_tokens) AS cached_input_tokens,
                    MAX(output_tokens) AS output_tokens,
                    MAX(request_count) AS request_count,
                    MAX(updated_at_unix_ms) AS updated_at_unix_ms
                FROM session_usage_minutes
                WHERE codex_home_path = ?
            """
            if rangeStartUnixMs != nil {
                sql += " AND minute_start_unix_ms >= ?"
            }
            if rangeEndUnixMs != nil {
                sql += " AND minute_start_unix_ms < ?"
            }
            sql += """
                GROUP BY logical_session_id, minute_start_unix_ms
            )
            GROUP BY minute_start_unix_ms
            ORDER BY minute_start_unix_ms ASC;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 21, fallback: "Failed to prepare projected minute aggregation.")
            }
            defer { sqlite3_finalize(statement) }

            var bindIndex: Int32 = 1
            sqlite3_bind_text(statement, bindIndex, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            bindIndex += 1
            if let rangeStartUnixMs {
                sqlite3_bind_int64(statement, bindIndex, rangeStartUnixMs)
                bindIndex += 1
            }
            if let rangeEndUnixMs {
                sqlite3_bind_int64(statement, bindIndex, rangeEndUnixMs)
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                let minuteStartUnixMs = sqlite3_column_int64(statement, 0)
                let totals = CodexSessionTokenTotals(
                    inputTokens: Int(sqlite3_column_int64(statement, 1)),
                    cachedInputTokens: Int(sqlite3_column_int64(statement, 2)),
                    outputTokens: Int(sqlite3_column_int64(statement, 3)),
                    requestCount: Int(sqlite3_column_int64(statement, 4))
                )
                let updatedAtUnixMs = sqlite3_column_int64(statement, 5)
                handleRow(minuteStartUnixMs, totals, updatedAtUnixMs)
            }
        }
    }

    private func loadAggregatedLogicalSessionUsage(
        codexHomePath: String,
        rolloutPaths: Set<String>
    ) throws -> CodexSessionTokenTotals? {
        guard !rolloutPaths.isEmpty else { return nil }
        return try withDatabase { db in
            let placeholders = Array(repeating: "?", count: rolloutPaths.count).joined(separator: ", ")
            let sql = """
            SELECT
                SUM(input_tokens) AS input_tokens,
                SUM(cached_input_tokens) AS cached_input_tokens,
                SUM(output_tokens) AS output_tokens,
                SUM(request_count) AS request_count
            FROM (
                SELECT
                    minute_start_unix_ms,
                    MAX(input_tokens) AS input_tokens,
                    MAX(cached_input_tokens) AS cached_input_tokens,
                    MAX(output_tokens) AS output_tokens,
                    MAX(request_count) AS request_count
                FROM session_usage_minutes
                WHERE codex_home_path = ? AND rollout_path IN (\(placeholders))
                GROUP BY minute_start_unix_ms
            );
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 22, fallback: "Failed to prepare logical rollout usage aggregation.")
            }
            defer { sqlite3_finalize(statement) }

            var bindIndex: Int32 = 1
            sqlite3_bind_text(statement, bindIndex, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            bindIndex += 1
            for rolloutPath in rolloutPaths.sorted() {
                sqlite3_bind_text(statement, bindIndex, rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                bindIndex += 1
            }

            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return Self.makeOptionalTotals(statement: statement)
        }
    }

    private func loadAggregatedLogicalSessionUsage(
        codexHomePath: String,
        sessionID: String
    ) throws -> CodexSessionTokenTotals? {
        try withDatabase { db in
            let sql = """
            SELECT
                SUM(input_tokens) AS input_tokens,
                SUM(cached_input_tokens) AS cached_input_tokens,
                SUM(output_tokens) AS output_tokens,
                SUM(request_count) AS request_count
            FROM (
                SELECT
                    minute_start_unix_ms,
                    MAX(input_tokens) AS input_tokens,
                    MAX(cached_input_tokens) AS cached_input_tokens,
                    MAX(output_tokens) AS output_tokens,
                    MAX(request_count) AS request_count
                FROM session_usage_minutes
                WHERE codex_home_path = ? AND session_id = ?
                GROUP BY minute_start_unix_ms
            );
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 23, fallback: "Failed to prepare logical session usage aggregation.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, sessionID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return Self.makeOptionalTotals(statement: statement)
        }
    }

    private func replaceMinuteEntries(
        codexHomePath: String,
        rolloutPath: String,
        sessionID: String?,
        minuteBuckets: [Int64: CodexSessionTokenTotals],
        updatedAtUnixMs: Int64
    ) throws {
        try withDatabase { db in
            try deleteMinuteEntries(
                db: db,
                codexHomePath: codexHomePath,
                rolloutPath: rolloutPath
            )
            try upsertMinuteEntries(
                db: db,
                codexHomePath: codexHomePath,
                rolloutPath: rolloutPath,
                sessionID: sessionID,
                minuteBuckets: minuteBuckets,
                updatedAtUnixMs: updatedAtUnixMs
            )
        }
    }

    private func upsertMinuteEntries(
        codexHomePath: String,
        rolloutPath: String,
        sessionID: String?,
        minuteBuckets: [Int64: CodexSessionTokenTotals],
        updatedAtUnixMs: Int64
    ) throws {
        try withDatabase { db in
            try upsertMinuteEntries(
                db: db,
                codexHomePath: codexHomePath,
                rolloutPath: rolloutPath,
                sessionID: sessionID,
                minuteBuckets: minuteBuckets,
                updatedAtUnixMs: updatedAtUnixMs
            )
        }
    }

    private func upsertMinuteEntries(
        db: OpaquePointer?,
        codexHomePath: String,
        rolloutPath: String,
        sessionID: String?,
        minuteBuckets: [Int64: CodexSessionTokenTotals],
        updatedAtUnixMs: Int64
    ) throws {
        guard !minuteBuckets.isEmpty else { return }

        let sql = """
        INSERT INTO session_usage_minutes (
            codex_home_path,
            rollout_path,
            session_id,
            minute_start_unix_ms,
            input_tokens,
            cached_input_tokens,
            output_tokens,
            request_count,
            updated_at_unix_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(codex_home_path, rollout_path, minute_start_unix_ms) DO UPDATE SET
            session_id = excluded.session_id,
            input_tokens = session_usage_minutes.input_tokens + excluded.input_tokens,
            cached_input_tokens = session_usage_minutes.cached_input_tokens + excluded.cached_input_tokens,
            output_tokens = session_usage_minutes.output_tokens + excluded.output_tokens,
            request_count = session_usage_minutes.request_count + excluded.request_count,
            updated_at_unix_ms = excluded.updated_at_unix_ms;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Self.sqliteError(db: db, code: 12, fallback: "Failed to prepare minute upsert.")
        }
        defer { sqlite3_finalize(statement) }

        for minuteStartUnixMs in minuteBuckets.keys.sorted() {
            let totals = minuteBuckets[minuteStartUnixMs] ?? .init(inputTokens: 0, cachedInputTokens: 0, outputTokens: 0, requestCount: 0)
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)

            sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            Self.bindOptionalText(sessionID, to: statement, at: 3)
            sqlite3_bind_int64(statement, 4, minuteStartUnixMs)
            sqlite3_bind_int64(statement, 5, Int64(totals.inputTokens))
            sqlite3_bind_int64(statement, 6, Int64(totals.cachedInputTokens))
            sqlite3_bind_int64(statement, 7, Int64(totals.outputTokens))
            sqlite3_bind_int64(statement, 8, Int64(totals.requestCount))
            sqlite3_bind_int64(statement, 9, updatedAtUnixMs)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.sqliteError(db: db, code: 13, fallback: "Failed to write minute entry.")
            }
        }
    }

    private func updateMinuteEntrySessionID(
        codexHomePath: String,
        rolloutPath: String,
        sessionID: String?
    ) throws {
        try withDatabase { db in
            let sql = """
            UPDATE session_usage_minutes
            SET session_id = ?
            WHERE codex_home_path = ? AND rollout_path = ?;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 14, fallback: "Failed to prepare minute session update.")
            }
            defer { sqlite3_finalize(statement) }

            Self.bindOptionalText(sessionID, to: statement, at: 1)
            sqlite3_bind_text(statement, 2, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 3, rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.sqliteError(db: db, code: 15, fallback: "Failed to update minute session ids.")
            }
        }
    }

    private func deleteMinuteEntries(
        db: OpaquePointer?,
        codexHomePath: String,
        rolloutPath: String
    ) throws {
        let sql = """
        DELETE FROM session_usage_minutes
        WHERE codex_home_path = ? AND rollout_path = ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Self.sqliteError(db: db, code: 16, fallback: "Failed to prepare minute delete.")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, codexHomePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, rolloutPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw Self.sqliteError(db: db, code: 17, fallback: "Failed to delete minute entries.")
        }
    }

    private static func mergeLogicalMinutes(
        from rows: [CodexSessionUsageMinuteEntry]
    ) -> [CodexSessionLogicalMinuteKey: CodexSessionTokenTotals] {
        rows.reduce(into: [:]) { partialResult, row in
            let key = CodexSessionLogicalMinuteKey(
                logicalSessionID: logicalSessionID(for: row),
                minuteStartUnixMs: row.minuteStartUnixMs
            )
            let existing = partialResult[key]
            partialResult[key] = .init(
                inputTokens: max(existing?.inputTokens ?? 0, row.inputTokens),
                cachedInputTokens: max(existing?.cachedInputTokens ?? 0, row.cachedInputTokens),
                outputTokens: max(existing?.outputTokens ?? 0, row.outputTokens),
                requestCount: max(existing?.requestCount ?? 0, row.requestCount)
            )
        }
    }

    private static func mergeMinutesWithinLogicalSession(
        from rows: [CodexSessionUsageMinuteEntry]
    ) -> [Int64: CodexSessionTokenTotals] {
        rows.reduce(into: [:]) { partialResult, row in
            let existing = partialResult[row.minuteStartUnixMs]
            partialResult[row.minuteStartUnixMs] = .init(
                inputTokens: max(existing?.inputTokens ?? 0, row.inputTokens),
                cachedInputTokens: max(existing?.cachedInputTokens ?? 0, row.cachedInputTokens),
                outputTokens: max(existing?.outputTokens ?? 0, row.outputTokens),
                requestCount: max(existing?.requestCount ?? 0, row.requestCount)
            )
        }
    }

    private static func logicalSessionID(for row: CodexSessionUsageMinuteEntry) -> String {
        normalizedSessionID(row.sessionID) ?? "rollout:\(row.rolloutPath)"
    }

    private static func normalizedSessionID(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    private static func makeOptionalTotals(statement: OpaquePointer?) -> CodexSessionTokenTotals? {
        guard sqlite3_column_type(statement, 0) != SQLITE_NULL,
              sqlite3_column_type(statement, 1) != SQLITE_NULL,
              sqlite3_column_type(statement, 2) != SQLITE_NULL
        else {
            return nil
        }
        return .init(
            inputTokens: Int(sqlite3_column_int64(statement, 0)),
            cachedInputTokens: Int(sqlite3_column_int64(statement, 1)),
            outputTokens: Int(sqlite3_column_int64(statement, 2)),
            requestCount: sqlite3_column_type(statement, 3) == SQLITE_NULL ? 0 : Int(sqlite3_column_int64(statement, 3))
        )
    }

    private func ensureColumnIfNeeded(
        db: OpaquePointer?,
        table: String,
        column: String,
        definition: String
    ) throws {
        let pragmaSQL = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, pragmaSQL, -1, &statement, nil) == SQLITE_OK else {
            throw Self.sqliteError(db: db, code: 7, fallback: "Failed to inspect usage index schema.")
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
               name == column {
                return
            }
        }

        let alterSQL = "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);"
        guard sqlite3_exec(db, alterSQL, nil, nil, nil) == SQLITE_OK else {
            throw Self.sqliteError(db: db, code: 8, fallback: "Failed to migrate usage index schema.")
        }
    }

    private static func fallbackTimeline(
        from fingerprint: CodexSessionUsageFileFingerprint
    ) -> CodexSessionTimeline? {
        guard fingerprint.modifiedAtUnixMs > 0 else { return nil }
        return .init(
            startedAt: nil,
            lastActivityAt: date(fromUnixMilliseconds: fingerprint.modifiedAtUnixMs)
        )
    }

    private static func unixMilliseconds(_ date: Date?) -> Int64? {
        guard let date else { return nil }
        return Int64((date.timeIntervalSince1970 * 1_000.0).rounded())
    }

    private static func date(fromUnixMilliseconds unixMilliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(unixMilliseconds) / 1_000)
    }

    private static func minuteStartUnixMilliseconds(for date: Date) -> Int64 {
        let unixSeconds = Int64(date.timeIntervalSince1970.rounded(.down))
        return (unixSeconds / 60) * 60 * 1_000
    }

    private static func parseISO8601(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        return fallbackFormatter.date(from: raw)
    }

    private static func currentUnixMs() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1_000.0).rounded())
    }

    private static func bindOptionalText(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private static func bindOptionalInt64(_ value: Int64?, to statement: OpaquePointer?, at index: Int32) {
        if let value {
            sqlite3_bind_int64(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private static func sqliteText(_ statement: OpaquePointer?, column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, column) else {
            return nil
        }
        return String(cString: value)
    }

    private static func sqliteInt64(_ statement: OpaquePointer?, column: Int32) -> Int64? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(statement, column)
    }

    private static func sqliteInt(_ statement: OpaquePointer?, column: Int32) -> Int? {
        guard let value = sqliteInt64(statement, column: column) else { return nil }
        return Int(value)
    }

    private static func sqliteError(
        db: OpaquePointer?,
        code: Int,
        fallback: String
    ) -> NSError {
        let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? fallback
        return NSError(
            domain: "CodexSessionUsageIndex.SQLite",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? fallback : message]
        )
    }
}
