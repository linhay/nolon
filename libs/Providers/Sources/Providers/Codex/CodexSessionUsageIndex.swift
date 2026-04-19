import Foundation
import SQLite3

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
    let source: CodexSessionUsageLoadSource
}

struct CodexSessionUsageIndexEntry: Equatable, Sendable {
    let codexHomePath: String
    let rolloutPath: String
    let absoluteRolloutPath: String
    let sessionID: String?
    let fileID: Int64?
    let modifiedAtUnixMs: Int64
    let sizeBytes: Int64
    let parsedBytes: Int64
    let lastModel: String?
    let totals: CodexSessionTokenTotals?
    let updatedAtUnixMs: Int64
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
    let parsedBytes: Int64
}

final class CodexSessionUsageIndex: @unchecked Sendable {
    private let fileManager: FileManager
    private let databaseURL: URL

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        let root: URL
        if let rootDirectory {
            root = rootDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            root = appSupport
                .appendingPathComponent("Nolon", isDirectory: true)
                .appendingPathComponent("codex-sessions", isDirectory: true)
        }
        self.databaseURL = root.appendingPathComponent("usage-index-v1.sqlite", isDirectory: false)
    }

    func load(
        codexHome: URL,
        rolloutPath: String
    ) throws -> CodexSessionUsageLoadResult {
        let resolvedRolloutURL = Self.resolveRolloutURL(codexHome: codexHome, rolloutPath: rolloutPath)
        guard fileManager.fileExists(atPath: resolvedRolloutURL.path) else {
            try deleteEntry(codexHomePath: codexHome.path, rolloutPath: rolloutPath)
            return .init(sessionID: nil, totals: nil, source: .fileMissing)
        }

        let fingerprint = try Self.fileFingerprint(
            fileManager: fileManager,
            url: resolvedRolloutURL
        )
        let cachedEntry = try loadEntry(codexHomePath: codexHome.path, rolloutPath: rolloutPath)

        if let cachedEntry,
           Self.matchesCache(entry: cachedEntry, fingerprint: fingerprint) {
            return .init(
                sessionID: cachedEntry.sessionID,
                totals: cachedEntry.totals,
                source: .cacheHit
            )
        }

        let parseResult: CodexSessionUsageParseResult
        let source: CodexSessionUsageLoadSource

        if let cachedEntry,
           Self.canUseAppendDelta(entry: cachedEntry, fingerprint: fingerprint) {
            do {
                parseResult = try Self.parseUsageFile(
                    at: resolvedRolloutURL,
                    fromOffset: cachedEntry.parsedBytes,
                    currentModel: cachedEntry.lastModel,
                    currentTotals: cachedEntry.totals,
                    sessionID: cachedEntry.sessionID
                )
                source = .deltaAppend
            } catch {
                parseResult = try Self.parseUsageFile(
                    at: resolvedRolloutURL,
                    fromOffset: 0,
                    currentModel: nil,
                    currentTotals: nil,
                    sessionID: nil
                )
                source = .fullRebuild
            }
        } else {
            parseResult = try Self.parseUsageFile(
                at: resolvedRolloutURL,
                fromOffset: 0,
                currentModel: nil,
                currentTotals: nil,
                sessionID: nil
            )
            source = .fullRebuild
        }

        try upsert(
            .init(
                codexHomePath: codexHome.path,
                rolloutPath: rolloutPath,
                absoluteRolloutPath: resolvedRolloutURL.path,
                sessionID: parseResult.sessionID,
                fileID: fingerprint.fileID,
                modifiedAtUnixMs: fingerprint.modifiedAtUnixMs,
                sizeBytes: fingerprint.sizeBytes,
                parsedBytes: parseResult.parsedBytes,
                lastModel: parseResult.lastModel,
                totals: parseResult.totals,
                updatedAtUnixMs: Self.currentUnixMs()
            )
        )

        return .init(
            sessionID: parseResult.sessionID,
            totals: parseResult.totals,
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
                file_id,
                mtime_unix_ms,
                size_bytes,
                parsed_bytes,
                last_model,
                input_tokens,
                cached_input_tokens,
                output_tokens,
                updated_at_unix_ms
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

    private func upsert(_ entry: CodexSessionUsageIndexEntry) throws {
        try withDatabase { db in
            let sql = """
            INSERT INTO usage_entries (
                codex_home_path,
                rollout_path,
                absolute_rollout_path,
                session_id,
                file_id,
                mtime_unix_ms,
                size_bytes,
                parsed_bytes,
                last_model,
                input_tokens,
                cached_input_tokens,
                output_tokens,
                updated_at_unix_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(codex_home_path, rollout_path) DO UPDATE SET
                absolute_rollout_path = excluded.absolute_rollout_path,
                session_id = excluded.session_id,
                file_id = excluded.file_id,
                mtime_unix_ms = excluded.mtime_unix_ms,
                size_bytes = excluded.size_bytes,
                parsed_bytes = excluded.parsed_bytes,
                last_model = excluded.last_model,
                input_tokens = excluded.input_tokens,
                cached_input_tokens = excluded.cached_input_tokens,
                output_tokens = excluded.output_tokens,
                updated_at_unix_ms = excluded.updated_at_unix_ms;
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
            Self.bindOptionalInt64(entry.fileID, to: statement, at: 5)
            sqlite3_bind_int64(statement, 6, entry.modifiedAtUnixMs)
            sqlite3_bind_int64(statement, 7, entry.sizeBytes)
            sqlite3_bind_int64(statement, 8, entry.parsedBytes)
            Self.bindOptionalText(entry.lastModel, to: statement, at: 9)
            Self.bindOptionalInt64(entry.totals.map { Int64($0.inputTokens) }, to: statement, at: 10)
            Self.bindOptionalInt64(entry.totals.map { Int64($0.cachedInputTokens) }, to: statement, at: 11)
            Self.bindOptionalInt64(entry.totals.map { Int64($0.outputTokens) }, to: statement, at: 12)
            sqlite3_bind_int64(statement, 13, entry.updatedAtUnixMs)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.sqliteError(db: db, code: 4, fallback: "Failed to write usage entry.")
            }
        }
    }

    private func deleteEntry(codexHomePath: String, rolloutPath: String) throws {
        try withDatabase { db in
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
                file_id INTEGER,
                mtime_unix_ms INTEGER NOT NULL,
                size_bytes INTEGER NOT NULL,
                parsed_bytes INTEGER NOT NULL,
                last_model TEXT,
                input_tokens INTEGER,
                cached_input_tokens INTEGER,
                output_tokens INTEGER,
                updated_at_unix_ms INTEGER NOT NULL,
                PRIMARY KEY (codex_home_path, rollout_path)
            );
            CREATE INDEX IF NOT EXISTS usage_entries_session_id_idx
            ON usage_entries (codex_home_path, session_id);
            """,
            nil,
            nil,
            nil
        )

        return try body(db)
    }

    private static func makeEntry(statement: OpaquePointer?) -> CodexSessionUsageIndexEntry {
        let inputTokens = sqliteInt(statement, column: 9)
        let cachedInputTokens = sqliteInt(statement, column: 10)
        let outputTokens = sqliteInt(statement, column: 11)
        let totals: CodexSessionTokenTotals?
        if let inputTokens, let cachedInputTokens, let outputTokens {
            totals = .init(
                inputTokens: inputTokens,
                cachedInputTokens: cachedInputTokens,
                outputTokens: outputTokens
            )
        } else {
            totals = nil
        }

        return .init(
            codexHomePath: sqliteText(statement, column: 0) ?? "",
            rolloutPath: sqliteText(statement, column: 1) ?? "",
            absoluteRolloutPath: sqliteText(statement, column: 2) ?? "",
            sessionID: sqliteText(statement, column: 3),
            fileID: sqliteInt64(statement, column: 4),
            modifiedAtUnixMs: sqliteInt64(statement, column: 5) ?? 0,
            sizeBytes: sqliteInt64(statement, column: 6) ?? 0,
            parsedBytes: sqliteInt64(statement, column: 7) ?? 0,
            lastModel: sqliteText(statement, column: 8),
            totals: totals,
            updatedAtUnixMs: sqliteInt64(statement, column: 12) ?? 0
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
        sessionID: String?
    ) throws -> CodexSessionUsageParseResult {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        if fromOffset > 0 {
            try handle.seek(toOffset: UInt64(fromOffset))
        }
        let data = try handle.readToEnd() ?? Data()

        var nextSessionID = sessionID
        var nextModel = currentModel
        var nextTotals = currentTotals

        for rawLine in data.split(separator: 0x0A) {
            guard !rawLine.isEmpty else { continue }
            let reduction = CodexSessionEventParser.reduceUsageLine(
                data: Data(rawLine),
                currentModel: nextModel,
                previousTotals: nextTotals
            )
            if let updatedSessionID = reduction?.sessionID {
                nextSessionID = updatedSessionID
            }
            if let updatedModel = reduction?.updatedModel {
                nextModel = updatedModel
            }
            if let updatedTotals = reduction?.updatedTotals {
                nextTotals = updatedTotals
            }
        }

        return .init(
            sessionID: nextSessionID,
            lastModel: nextModel,
            totals: nextTotals,
            parsedBytes: fromOffset + Int64(data.count)
        )
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
