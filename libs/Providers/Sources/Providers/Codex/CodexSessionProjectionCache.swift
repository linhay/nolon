import Foundation
import SQLite3

final class CodexSessionProjectionCache: @unchecked Sendable {
    private enum SnapshotKind: String {
        case sessionSnapshot = "session_snapshot"
        case projectSkeleton = "project_skeleton"
    }

    private struct SessionRecordPayload: Codable, Equatable {
        let id: String
        let threadID: String?
        let title: String?
        let summary: String?
        let forkedFromID: String?
        let originator: String?
        let source: String?
        let modelProvider: String
        let archived: Bool
        let rolloutPath: String
        let cwd: String?
        let updatedAtUnixMs: Int64?
        let stateRowCount: Int
        let editable: Bool

        init(record: CodexSessionRecord) {
            id = record.id
            threadID = record.threadID
            title = record.title
            summary = record.summary
            forkedFromID = record.forkedFromID
            originator = record.originator
            source = record.source
            modelProvider = record.modelProvider
            archived = record.archived
            rolloutPath = record.rolloutPath
            cwd = record.cwd
            updatedAtUnixMs = record.updatedAt.map(Self.unixMilliseconds)
            stateRowCount = record.stateRowCount
            editable = record.editable
        }

        var record: CodexSessionRecord {
            .init(
                id: id,
                threadID: threadID,
                title: title,
                summary: summary,
                forkedFromID: forkedFromID,
                originator: originator,
                source: source,
                modelProvider: modelProvider,
                archived: archived,
                rolloutPath: rolloutPath,
                cwd: cwd,
                updatedAt: updatedAtUnixMs.map { Self.date(from: $0) },
                stateRowCount: stateRowCount,
                editable: editable
            )
        }

        private static func unixMilliseconds(_ date: Date) -> Int64 {
            Int64((date.timeIntervalSince1970 * 1_000).rounded())
        }

        private static func date(from unixMilliseconds: Int64) -> Date {
            Date(timeIntervalSince1970: TimeInterval(unixMilliseconds) / 1_000)
        }
    }

    private struct SessionSnapshotPayload: Codable, Equatable {
        let sessions: [SessionRecordPayload]
        let availableProviderIDs: [String]

        init(snapshot: CodexSessionSnapshot) {
            sessions = snapshot.sessions.map(SessionRecordPayload.init(record:))
            availableProviderIDs = snapshot.availableProviderIDs
        }

        var snapshot: CodexSessionSnapshot {
            .init(
                sessions: sessions.map(\.record),
                availableProviderIDs: availableProviderIDs
            )
        }
    }

    private struct ProjectSkeletonPayload: Codable, Equatable {
        let projectPath: String?
        let liveCount: Int
        let archivedCount: Int
        let latestUpdatedAtUnixMs: Int64?

        init(project: CodexSessionProjectSkeleton) {
            projectPath = project.projectPath
            liveCount = project.liveCount
            archivedCount = project.archivedCount
            latestUpdatedAtUnixMs = project.latestUpdatedAt.map(Self.unixMilliseconds)
        }

        var project: CodexSessionProjectSkeleton {
            .init(
                projectPath: projectPath,
                liveCount: liveCount,
                archivedCount: archivedCount,
                latestUpdatedAt: latestUpdatedAtUnixMs.map { Self.date(from: $0) }
            )
        }

        private static func unixMilliseconds(_ date: Date) -> Int64 {
            Int64((date.timeIntervalSince1970 * 1_000).rounded())
        }

        private static func date(from unixMilliseconds: Int64) -> Date {
            Date(timeIntervalSince1970: TimeInterval(unixMilliseconds) / 1_000)
        }
    }

    private struct ProjectSkeletonSnapshotPayload: Codable, Equatable {
        let projects: [ProjectSkeletonPayload]
        let availableProviderIDs: [String]

        init(snapshot: CodexSessionProjectSkeletonSnapshot) {
            projects = snapshot.projects.map(ProjectSkeletonPayload.init(project:))
            availableProviderIDs = snapshot.availableProviderIDs
        }

        var snapshot: CodexSessionProjectSkeletonSnapshot {
            .init(
                projects: projects.map(\.project),
                availableProviderIDs: availableProviderIDs
            )
        }
    }

    private static let schemaVersion = 1

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
        databaseURL = root.appendingPathComponent("projection-cache-v1.sqlite", isDirectory: false)
    }

    func loadSnapshot(codexHome: URL) throws -> CodexSessionSnapshot? {
        guard let payload = try loadPayload(codexHome: codexHome, kind: .sessionSnapshot, as: SessionSnapshotPayload.self) else {
            return nil
        }
        return payload.snapshot
    }

    func loadStatus(codexHome: URL) throws -> CodexSessionProjectionStatus? {
        try withDatabase { db in
            let sql = """
            SELECT
                is_dirty,
                last_source_change_at_unix_ms,
                last_snapshot_written_at_unix_ms,
                last_skeleton_written_at_unix_ms
            FROM projection_status
            WHERE codex_home_path = ?
            LIMIT 1;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 10, fallback: "Failed to prepare projection status read.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHome.standardizedFileURL.path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }

            return CodexSessionProjectionStatus(
                isDirty: sqlite3_column_int(statement, 0) != 0,
                lastSourceChangeAt: Self.date(column: 1, statement: statement),
                snapshotUpdatedAt: Self.date(column: 2, statement: statement),
                skeletonUpdatedAt: Self.date(column: 3, statement: statement)
            )
        }
    }

    func saveSnapshot(
        _ snapshot: CodexSessionSnapshot,
        codexHome: URL,
        sourceRunID: String?
    ) throws {
        try savePayload(
            SessionSnapshotPayload(snapshot: snapshot),
            codexHome: codexHome,
            kind: .sessionSnapshot,
            sourceRunID: sourceRunID
        )
    }

    func loadProjectSkeletonSnapshot(codexHome: URL) throws -> CodexSessionProjectSkeletonSnapshot? {
        guard let payload = try loadPayload(
            codexHome: codexHome,
            kind: .projectSkeleton,
            as: ProjectSkeletonSnapshotPayload.self
        ) else {
            return nil
        }
        return payload.snapshot
    }

    func saveProjectSkeletonSnapshot(
        _ snapshot: CodexSessionProjectSkeletonSnapshot,
        codexHome: URL,
        sourceRunID: String?
    ) throws {
        try savePayload(
            ProjectSkeletonSnapshotPayload(snapshot: snapshot),
            codexHome: codexHome,
            kind: .projectSkeleton,
            sourceRunID: sourceRunID
        )
    }

    func markDirty(codexHome: URL) throws {
        try withDatabase { db in
            try upsertStatus(
                codexHome: codexHome,
                isDirty: true,
                lastSourceChangeAtUnixMs: Self.unixMilliseconds(Date()),
                snapshotUpdatedAtUnixMs: nil,
                skeletonUpdatedAtUnixMs: nil,
                db: db
            )
        }
    }

    func invalidate(codexHome: URL) throws {
        try withDatabase { db in
            let sql = "DELETE FROM projection_snapshots WHERE codex_home_path = ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 3, fallback: "Failed to prepare projection cache invalidation.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHome.standardizedFileURL.path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.sqliteError(db: db, code: 4, fallback: "Failed to invalidate projection cache.")
            }

            try upsertStatus(
                codexHome: codexHome,
                isDirty: true,
                lastSourceChangeAtUnixMs: Self.unixMilliseconds(Date()),
                snapshotUpdatedAtUnixMs: nil,
                skeletonUpdatedAtUnixMs: nil,
                db: db
            )
        }
    }

    private func loadPayload<Payload: Decodable>(
        codexHome: URL,
        kind: SnapshotKind,
        as payloadType: Payload.Type
    ) throws -> Payload? {
        try withDatabase { db in
            let sql = """
            SELECT schema_version, payload_json
            FROM projection_snapshots
            WHERE codex_home_path = ? AND kind = ?
            LIMIT 1;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 5, fallback: "Failed to prepare projection cache read.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHome.standardizedFileURL.path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, kind.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }

            let schemaVersion = Int(sqlite3_column_int(statement, 0))
            guard schemaVersion == Self.schemaVersion else {
                try deleteEntry(codexHome: codexHome, kind: kind, db: db)
                return nil
            }

            guard let payloadCString = sqlite3_column_text(statement, 1) else {
                return nil
            }
            let payloadJSON = String(cString: payloadCString)
            let decoder = JSONDecoder()
            guard let data = payloadJSON.data(using: .utf8) else {
                try deleteEntry(codexHome: codexHome, kind: kind, db: db)
                return nil
            }
            do {
                return try decoder.decode(payloadType, from: data)
            } catch {
                try deleteEntry(codexHome: codexHome, kind: kind, db: db)
                return nil
            }
        }
    }

    private func savePayload<Payload: Encodable>(
        _ payload: Payload,
        codexHome: URL,
        kind: SnapshotKind,
        sourceRunID: String?
    ) throws {
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)
        guard let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            throw NSError(
                domain: "CodexSessionProjectionCache.Encoding",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode projection cache payload."]
            )
        }

        try withDatabase { db in
            let writtenAt = Self.unixMilliseconds(Date())
            let sql = """
            INSERT INTO projection_snapshots (
                codex_home_path,
                kind,
                schema_version,
                payload_json,
                updated_at_unix_ms,
                source_run_id
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(codex_home_path, kind) DO UPDATE SET
                schema_version = excluded.schema_version,
                payload_json = excluded.payload_json,
                updated_at_unix_ms = excluded.updated_at_unix_ms,
                source_run_id = excluded.source_run_id;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw Self.sqliteError(db: db, code: 6, fallback: "Failed to prepare projection cache write.")
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, codexHome.standardizedFileURL.path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, kind.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int(statement, 3, Int32(Self.schemaVersion))
            sqlite3_bind_text(statement, 4, payloadJSON, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int64(statement, 5, writtenAt)
            if let sourceRunID {
                sqlite3_bind_text(statement, 6, sourceRunID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                sqlite3_bind_null(statement, 6)
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw Self.sqliteError(db: db, code: 7, fallback: "Failed to write projection cache.")
            }

            switch kind {
            case .sessionSnapshot:
                try upsertStatus(
                    codexHome: codexHome,
                    isDirty: false,
                    lastSourceChangeAtUnixMs: nil,
                    snapshotUpdatedAtUnixMs: writtenAt,
                    skeletonUpdatedAtUnixMs: nil,
                    db: db
                )
            case .projectSkeleton:
                try upsertStatus(
                    codexHome: codexHome,
                    isDirty: nil,
                    lastSourceChangeAtUnixMs: nil,
                    snapshotUpdatedAtUnixMs: nil,
                    skeletonUpdatedAtUnixMs: writtenAt,
                    db: db
                )
            }
        }
    }

    private func upsertStatus(
        codexHome: URL,
        isDirty: Bool?,
        lastSourceChangeAtUnixMs: Int64?,
        snapshotUpdatedAtUnixMs: Int64?,
        skeletonUpdatedAtUnixMs: Int64?,
        db: OpaquePointer?
    ) throws {
        let sql = """
        INSERT INTO projection_status (
            codex_home_path,
            is_dirty,
            last_source_change_at_unix_ms,
            last_snapshot_written_at_unix_ms,
            last_skeleton_written_at_unix_ms
        ) VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(codex_home_path) DO UPDATE SET
            is_dirty = COALESCE(excluded.is_dirty, projection_status.is_dirty),
            last_source_change_at_unix_ms = COALESCE(excluded.last_source_change_at_unix_ms, projection_status.last_source_change_at_unix_ms),
            last_snapshot_written_at_unix_ms = COALESCE(excluded.last_snapshot_written_at_unix_ms, projection_status.last_snapshot_written_at_unix_ms),
            last_skeleton_written_at_unix_ms = COALESCE(excluded.last_skeleton_written_at_unix_ms, projection_status.last_skeleton_written_at_unix_ms);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Self.sqliteError(db: db, code: 11, fallback: "Failed to prepare projection status write.")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, codexHome.standardizedFileURL.path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        if let isDirty {
            sqlite3_bind_int(statement, 2, isDirty ? 1 : 0)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        Self.bindInt64(lastSourceChangeAtUnixMs, to: statement, index: 3)
        Self.bindInt64(snapshotUpdatedAtUnixMs, to: statement, index: 4)
        Self.bindInt64(skeletonUpdatedAtUnixMs, to: statement, index: 5)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw Self.sqliteError(db: db, code: 12, fallback: "Failed to write projection status.")
        }
    }

    private func deleteEntry(
        codexHome: URL,
        kind: SnapshotKind,
        db: OpaquePointer?
    ) throws {
        let sql = "DELETE FROM projection_snapshots WHERE codex_home_path = ? AND kind = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Self.sqliteError(db: db, code: 8, fallback: "Failed to prepare projection cache deletion.")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, codexHome.standardizedFileURL.path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, kind.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw Self.sqliteError(db: db, code: 9, fallback: "Failed to delete stale projection cache entry.")
        }
    }

    private func withDatabase<T>(_ body: (OpaquePointer?) throws -> T) throws -> T {
        try fileManager.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var db: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Failed to open projection cache database."
            sqlite3_close(db)
            throw NSError(
                domain: "CodexSessionProjectionCache.SQLite",
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
            CREATE TABLE IF NOT EXISTS projection_snapshots (
                codex_home_path TEXT NOT NULL,
                kind TEXT NOT NULL,
                schema_version INTEGER NOT NULL,
                payload_json TEXT NOT NULL,
                updated_at_unix_ms INTEGER NOT NULL,
                source_run_id TEXT,
                PRIMARY KEY (codex_home_path, kind)
            );
            """,
            nil,
            nil,
            nil
        )
        _ = sqlite3_exec(
            db,
            """
            CREATE TABLE IF NOT EXISTS projection_status (
                codex_home_path TEXT NOT NULL PRIMARY KEY,
                is_dirty INTEGER,
                last_source_change_at_unix_ms INTEGER,
                last_snapshot_written_at_unix_ms INTEGER,
                last_skeleton_written_at_unix_ms INTEGER
            );
            """,
            nil,
            nil,
            nil
        )

        return try body(db)
    }

    private static func sqliteError(db: OpaquePointer?, code: Int, fallback: String) -> NSError {
        let message = db.map { String(cString: sqlite3_errmsg($0)) }?.trimmingCharacters(in: .whitespacesAndNewlines)
        return NSError(
            domain: "CodexSessionProjectionCache.SQLite",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message?.isEmpty == false ? message! : fallback]
        )
    }

    private static func unixMilliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    private static func bindInt64(_ value: Int64?, to statement: OpaquePointer?, index: Int32) {
        if let value {
            sqlite3_bind_int64(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private static func date(column: Int32, statement: OpaquePointer?) -> Date? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else {
            return nil
        }
        let unixMilliseconds = sqlite3_column_int64(statement, column)
        return Date(timeIntervalSince1970: TimeInterval(unixMilliseconds) / 1_000)
    }
}
