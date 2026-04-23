import Foundation
import SQLite3
import STFilePath
import Testing
@testable import CodexProvider

@Suite("CodexSessionStore")
struct CodexSessionStoreTests {
    private func makeTempRoot(_ prefix: String) throws -> STFolder {
        let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        return root
    }

    private func writeRolloutSessionMeta(
        codexHome: STFolder,
        threadID: String,
        timestamp: String,
        modelProvider: String?,
        archived: Bool = false,
        cwd: String = "/tmp/project",
        forkedFromID: String? = nil,
        originator: String? = nil,
        source: String? = "cli"
    ) throws -> STFile {
        let rootFolder = archived ? codexHome.folder("archived_sessions") : codexHome.folder("sessions")
        let dayFolder = rootFolder.folder("2026").folder("04").folder("10")
        _ = dayFolder.createIfNotExists()

        let file = dayFolder.file("rollout-2026-04-10T10-00-00-\(threadID).jsonl")
        var payload: [String: Any] = [
            "id": threadID,
            "timestamp": timestamp,
            "cwd": cwd,
        ]
        if let source {
            payload["source"] = source
        }
        if let modelProvider {
            payload["model_provider"] = modelProvider
        }
        if let forkedFromID {
            payload["forked_from_id"] = forkedFromID
        }
        if let originator {
            payload["originator"] = originator
        }

        let sessionMetaData = try JSONSerialization.data(withJSONObject: [
            "timestamp": timestamp,
            "type": "session_meta",
            "payload": payload,
        ])
        let userEventData = try JSONSerialization.data(withJSONObject: [
            "timestamp": "2026-04-10T10:00:01Z",
            "type": "response_item",
            "payload": [
                "type": "message",
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": "hello",
                    ]
                ]
            ]
        ])

        let content = [
            String(decoding: sessionMetaData, as: UTF8.self),
            String(decoding: userEventData, as: UTF8.self),
        ].joined(separator: "\n") + "\n"
        try file.overlay(with: content)
        return file
    }

    private func writeUsageRollout(
        codexHome: STFolder,
        rolloutPath: String = "sessions/usage.jsonl",
        sessionID: String = "session-1",
        model: String = "gpt-5",
        preludeLines: [String]? = nil,
        usageLines: [String]
    ) throws -> STFile {
        let file = codexHome.file(rolloutPath)
        _ = file.parentFolder()?.createIfNotExists()

        let defaultPrelude = try [
            makeSessionMetaLine(sessionID: sessionID),
            #"{"timestamp":"2026-04-10T10:00:01Z","type":"turn_context","payload":{"model":"\#(model)"}}"#,
        ]

        let content = ((preludeLines ?? defaultPrelude) + usageLines).joined(separator: "\n") + "\n"

        try file.overlay(with: content)
        return file
    }

    private func makeSessionMetaLine(
        sessionID: String,
        timestamp: String = "2026-04-10T10:00:00Z",
        forkedFromID: String? = nil,
        source: Any? = nil
    ) throws -> String {
        var payload: [String: Any] = [
            "id": sessionID,
        ]
        if let forkedFromID {
            payload["forked_from_id"] = forkedFromID
        }
        if let source {
            payload["source"] = source
        }

        let data = try JSONSerialization.data(withJSONObject: [
            "timestamp": timestamp,
            "type": "session_meta",
            "payload": payload,
        ])
        return String(decoding: data, as: UTF8.self)
    }

    private func appendRolloutLines(file: STFile, lines: [String]) throws {
        let suffix = lines.joined(separator: "\n") + "\n"
        if !file.isExists {
            try file.overlay(with: suffix)
            return
        }

        let handle = try FileHandle(forWritingTo: file.url)
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(suffix.utf8))
    }

    private func sqliteExecute(databaseURL: URL, sql: String, bindings: [SQLiteBinding] = []) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexSessionStoreTests.sqlite", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexSessionStoreTests.sqlite", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        for (index, binding) in bindings.enumerated() {
            let parameterIndex = Int32(index + 1)
            switch binding {
            case let .text(value):
                sqlite3_bind_text(statement, parameterIndex, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let .int64(value):
                sqlite3_bind_int64(statement, parameterIndex, value)
            case .null:
                sqlite3_bind_null(statement, parameterIndex)
            }
        }

        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexSessionStoreTests.sqlite", code: 3, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func createStateDatabase(
        codexHome: STFolder,
        threads: [(id: String, title: String, modelProvider: String, updatedAt: Int64?, archived: Bool)]
    ) throws {
        let databaseURL = codexHome.file("state_4.sqlite").url
        try sqliteExecute(
            databaseURL: databaseURL,
            sql: """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                title TEXT,
                model_provider TEXT NOT NULL,
                updated_at INTEGER,
                archived INTEGER NOT NULL DEFAULT 0
            );
            """
        )

        for thread in threads {
            try sqliteExecute(
                databaseURL: databaseURL,
                sql: """
                INSERT INTO threads (id, title, model_provider, updated_at, archived)
                VALUES (?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(thread.id),
                    .text(thread.title),
                    .text(thread.modelProvider),
                    thread.updatedAt.map(SQLiteBinding.int64) ?? .null,
                    .int64(thread.archived ? 1 : 0),
                ]
            )
        }
    }

    private func rolloutSessionMetaProvider(file: STFile) throws -> String? {
        let content = try file.read()
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (object["type"] as? String) == "session_meta",
                  let payload = object["payload"] as? [String: Any]
            else {
                continue
            }
            return payload["model_provider"] as? String
        }
        return nil
    }

    private func sqliteString(databaseURL: URL, sql: String, bind: String) throws -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "CodexSessionStoreTests.sqlite", code: 4, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "CodexSessionStoreTests.sqlite", code: 5, userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, bind, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        guard let value = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: value)
    }

    @Test("Given projection cache writes a session snapshot, when loading it back, then payload round trips")
    func projectionCacheRoundTripsSessionSnapshot() throws {
        let root = try makeTempRoot("codex-projection-cache")
        let codexHome = root.folder(".codex")
        _ = codexHome.createIfNotExists()
        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()

        let cache = CodexSessionProjectionCache(rootDirectory: cacheRoot.url)
        let snapshot = CodexSessionSnapshot(
            sessions: [
                .init(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    summary: "summary",
                    forkedFromID: nil,
                    originator: "codex",
                    source: "cli",
                    modelProvider: "openai",
                    archived: false,
                    rolloutPath: "sessions/a.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: Date(timeIntervalSince1970: 1_000),
                    stateRowCount: 1,
                    editable: true
                )
            ],
            availableProviderIDs: ["openai", "anthropic"]
        )

        try cache.saveSnapshot(snapshot, codexHome: codexHome.url, sourceRunID: "test-run")
        let loaded = try cache.loadSnapshot(codexHome: codexHome.url)

        #expect(loaded == snapshot)
    }

    @Test("Given xctest environment, when usage index uses default root, then writes under isolated app support")
    func usageIndexDefaultsToIsolatedApplicationSupportUnderXCTest() throws {
        let root = try makeTempRoot("codex-usage-index-default-root")
        let codexHome = root.folder(".codex")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/usage.jsonl",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:01:00Z","type":"token_count","payload":{"input_tokens":10,"output_tokens":4}}"#
            ]
        )

        let index = CodexSessionUsageIndex()
        _ = try index.load(codexHome: codexHome.url, rolloutPath: "sessions/usage.jsonl")

        let databaseURL = NolonHomeEnvironment.resolveApplicationSupportFolder(
            environment: ProcessInfo.processInfo.environment
        )
        .appendingPathComponent("Nolon", isDirectory: true)
        .appendingPathComponent("codex-sessions", isDirectory: true)
        .appendingPathComponent("usage-index-v1.sqlite", isDirectory: false)

        #expect(FileManager.default.fileExists(atPath: databaseURL.path))
    }

    @Test("Given projection cache writes a skeleton snapshot, when loading it back, then payload round trips")
    func projectionCacheRoundTripsProjectSkeletonSnapshot() throws {
        let root = try makeTempRoot("codex-projection-cache")
        let codexHome = root.folder(".codex")
        _ = codexHome.createIfNotExists()
        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()

        let cache = CodexSessionProjectionCache(rootDirectory: cacheRoot.url)
        let snapshot = CodexSessionProjectSkeletonSnapshot(
            projects: [
                .init(
                    projectPath: "/tmp/project-alpha",
                    liveCount: 10,
                    archivedCount: 2,
                    latestUpdatedAt: Date(timeIntervalSince1970: 2_000)
                )
            ],
            availableProviderIDs: ["openai"]
        )

        try cache.saveProjectSkeletonSnapshot(snapshot, codexHome: codexHome.url, sourceRunID: "test-run")
        let loaded = try cache.loadProjectSkeletonSnapshot(codexHome: codexHome.url)

        #expect(loaded == snapshot)
    }

    @Test("Given projection cache is marked dirty, when loading status, then dirty metadata is persisted")
    func projectionCachePersistsDirtyStatus() throws {
        let root = try makeTempRoot("codex-projection-cache-status")
        let codexHome = root.folder(".codex")
        _ = codexHome.createIfNotExists()
        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()

        let cache = CodexSessionProjectionCache(rootDirectory: cacheRoot.url)

        try cache.markDirty(codexHome: codexHome.url)
        let loadedStatus = try cache.loadStatus(codexHome: codexHome.url)
        let status = try #require(loadedStatus)

        #expect(status.isDirty == true)
        #expect(status.lastSourceChangeAt != nil)
        #expect(status.snapshotUpdatedAt == nil)
        #expect(status.skeletonUpdatedAt == nil)
    }

    @Test("Given projection cache is dirty, when saving snapshot, then dirty flag is cleared and snapshot timestamp is refreshed")
    func projectionCacheSnapshotWriteClearsDirtyStatus() throws {
        let root = try makeTempRoot("codex-projection-cache-snapshot-status")
        let codexHome = root.folder(".codex")
        _ = codexHome.createIfNotExists()
        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()

        let cache = CodexSessionProjectionCache(rootDirectory: cacheRoot.url)
        try cache.markDirty(codexHome: codexHome.url)

        let snapshot = CodexSessionSnapshot(
            sessions: [
                .init(
                    id: "sessions/a.jsonl",
                    threadID: "thread-a",
                    title: "Alpha",
                    summary: nil,
                    forkedFromID: nil,
                    originator: "codex",
                    source: "cli",
                    modelProvider: "openai",
                    archived: false,
                    rolloutPath: "sessions/a.jsonl",
                    cwd: "/tmp/project-alpha",
                    updatedAt: Date(timeIntervalSince1970: 1_000),
                    stateRowCount: 1,
                    editable: true
                )
            ],
            availableProviderIDs: ["openai"]
        )

        try cache.saveSnapshot(snapshot, codexHome: codexHome.url, sourceRunID: "refresh-run")
        let loadedStatus = try cache.loadStatus(codexHome: codexHome.url)
        let status = try #require(loadedStatus)

        #expect(status.isDirty == false)
        #expect(status.lastSourceChangeAt != nil)
        #expect(status.snapshotUpdatedAt != nil)
    }

    @Test("Given projection cache is dirty, when saving skeleton snapshot, then skeleton timestamp updates without clearing dirty")
    func projectionCacheSkeletonWritePreservesDirtyStatus() throws {
        let root = try makeTempRoot("codex-projection-cache-skeleton-status")
        let codexHome = root.folder(".codex")
        _ = codexHome.createIfNotExists()
        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()

        let cache = CodexSessionProjectionCache(rootDirectory: cacheRoot.url)
        try cache.markDirty(codexHome: codexHome.url)

        let snapshot = CodexSessionProjectSkeletonSnapshot(
            projects: [
                .init(
                    projectPath: "/tmp/project-alpha",
                    liveCount: 3,
                    archivedCount: 1,
                    latestUpdatedAt: Date(timeIntervalSince1970: 2_000)
                )
            ],
            availableProviderIDs: ["openai"]
        )

        try cache.saveProjectSkeletonSnapshot(snapshot, codexHome: codexHome.url, sourceRunID: "warmup-run")
        let loadedStatus = try cache.loadStatus(codexHome: codexHome.url)
        let status = try #require(loadedStatus)

        #expect(status.isDirty == true)
        #expect(status.skeletonUpdatedAt != nil)
        #expect(status.snapshotUpdatedAt == nil)
    }

    @Test("Given cached projection schema is stale, when loading snapshot, then cache is ignored")
    func projectionCacheIgnoresSchemaMismatch() throws {
        let root = try makeTempRoot("codex-projection-cache")
        let codexHome = root.folder(".codex")
        _ = codexHome.createIfNotExists()
        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()

        let cache = CodexSessionProjectionCache(rootDirectory: cacheRoot.url)
        let databaseURL = cacheRoot.url.appendingPathComponent("projection-cache-v1.sqlite", isDirectory: false)
        try sqliteExecute(
            databaseURL: databaseURL,
            sql: """
            CREATE TABLE IF NOT EXISTS projection_snapshots (
                codex_home_path TEXT NOT NULL,
                kind TEXT NOT NULL,
                schema_version INTEGER NOT NULL,
                payload_json TEXT NOT NULL,
                updated_at_unix_ms INTEGER NOT NULL,
                source_run_id TEXT,
                PRIMARY KEY (codex_home_path, kind)
            );
            """
        )
        try sqliteExecute(
            databaseURL: databaseURL,
            sql: """
            INSERT INTO projection_snapshots (
                codex_home_path,
                kind,
                schema_version,
                payload_json,
                updated_at_unix_ms,
                source_run_id
            ) VALUES (?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(codexHome.url.path),
                .text("session_snapshot"),
                .int64(999),
                .text(#"{"available_provider_ids":["openai"],"sessions":[]}"#),
                .int64(1_000),
                .text("legacy-run"),
            ]
        )

        let loaded = try cache.loadSnapshot(codexHome: codexHome.url)

        #expect(loaded == nil)
    }

    @Test("Given store loads a fresh snapshot, when reading cached projection, then persisted snapshot is available")
    func storePersistsProjectionSnapshotAfterLoadSnapshot() throws {
        let root = try makeTempRoot("codex-projection-cache")
        let codexHome = root.folder(".codex")
        _ = codexHome.createIfNotExists()
        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()

        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "thread-a",
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai",
            cwd: "/tmp/project-alpha"
        )
        try createStateDatabase(
            codexHome: codexHome,
            threads: [
                (
                    id: "thread-a",
                    title: "Alpha",
                    modelProvider: "openai",
                    updatedAt: 1_000,
                    archived: false
                )
            ]
        )

        let store = CodexSessionStore(
            usageIndexRootDirectory: cacheRoot.url,
            projectionCacheRootDirectory: cacheRoot.url,
            enableInventoryCache: false
        )

        let snapshot = try store.loadSnapshot(codexHome: codexHome)
        let cached = try store.loadCachedSnapshot(codexHome: codexHome.url)
        let status = try store.cachedProjectionStatus(codexHome: codexHome.url)

        #expect(cached == snapshot)
        #expect(status?.isDirty == false)
        #expect(status?.snapshotUpdatedAt != nil)
    }

    private func writeSessionIndex(
        codexHome: STFolder,
        entries: [(id: String, threadName: String, updatedAt: String)]
    ) throws {
        let file = codexHome.file("session_index.jsonl")
        let content = try entries.map { entry in
            let data = try JSONSerialization.data(withJSONObject: [
                "id": entry.id,
                "thread_name": entry.threadName,
                "updated_at": entry.updatedAt,
            ])
            return String(decoding: data, as: UTF8.self)
        }
        .joined(separator: "\n") + "\n"
        try file.overlay(with: content)
    }

    private func parseISO8601(_ raw: String) throws -> Date {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: raw) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try #require(formatter.date(from: raw))
    }

    @Test("Given session meta has blank provider and fractional timestamp, when loading snapshot, then store falls back to default provider and parses the timestamp")
    func loadSnapshotFallsBackToDefaultProviderAndParsesFractionalTimestamp() throws {
        let root = try makeTempRoot("codex-session-store-default-provider")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00.123Z",
            modelProvider: "   "
        )

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)
        let session = try #require(snapshot.sessions.first)
        let updatedAt = try #require(session.updatedAt)

        #expect(session.threadID == threadID)
        #expect(session.modelProvider == "openai")
        #expect(abs(updatedAt.timeIntervalSince1970 - 1775815200.123) < 0.001)
    }

    @Test("Given session meta omits provider and state db keeps a provider for the same thread, when loading snapshot, then store uses the normalized state provider")
    func loadSnapshotFallsBackToStateProviderWhenSessionMetaProviderIsMissing() throws {
        let root = try makeTempRoot("codex-session-store-state-provider")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: nil
        )
        try createStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: threadID, title: "Existing thread", modelProvider: " Provider-Relay ", updatedAt: nil, archived: false)
            ]
        )

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)
        let session = try #require(snapshot.sessions.first)

        #expect(session.modelProvider == "provider-relay")
        #expect(session.title == "Existing thread")
    }

    @Test("Given session meta thread id is blank, when loading snapshot, then store normalizes it to nil and marks the session read only")
    func loadSnapshotNormalizesBlankThreadIDToNil() throws {
        let root = try makeTempRoot("codex-session-store-blank-thread")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "   ",
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai"
        )

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)
        let session = try #require(snapshot.sessions.first)

        #expect(session.threadID == nil)
        #expect(session.editable == false)
    }

    @Test("Given rollout files span multiple projects, when loading project skeleton snapshot, then counts and latest timestamps are aggregated per project")
    func loadProjectSkeletonSnapshotAggregatesProjects() throws {
        let root = try makeTempRoot("codex-session-store-project-skeleton")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "alpha-live",
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai",
            cwd: "/tmp/project-alpha"
        )
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "alpha-archived",
            timestamp: "2026-04-10T12:00:00Z",
            modelProvider: "openai",
            archived: true,
            cwd: "/tmp/project-alpha"
        )
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "beta-live",
            timestamp: "2026-04-10T13:00:00Z",
            modelProvider: "anthropic",
            cwd: "/tmp/project-beta"
        )
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "unknown-live",
            timestamp: "2026-04-10T09:00:00Z",
            modelProvider: "gemini",
            cwd: "   "
        )

        let skeletonSnapshot = try CodexSessionStore(defaultProviderID: "openai")
            .loadProjectSkeletonSnapshot(codexHome: codexHome)

        #expect(skeletonSnapshot.projects.map(\.projectPath) == [
            "/tmp/project-beta",
            "/tmp/project-alpha",
            nil,
        ])
        let expectedBetaDate = try parseISO8601("2026-04-10T13:00:00Z")
        let expectedAlphaDate = try parseISO8601("2026-04-10T12:00:00Z")

        let beta = try #require(skeletonSnapshot.projects.first)
        #expect(beta.liveCount == 1)
        #expect(beta.archivedCount == 0)
        #expect(beta.latestUpdatedAt == expectedBetaDate)

        let alpha = try #require(skeletonSnapshot.projects.dropFirst().first)
        #expect(alpha.liveCount == 1)
        #expect(alpha.archivedCount == 1)
        #expect(alpha.latestUpdatedAt == expectedAlphaDate)

        let unknown = try #require(skeletonSnapshot.projects.last)
        #expect(unknown.liveCount == 1)
        #expect(unknown.archivedCount == 0)
        #expect(unknown.projectPath == nil)
    }

    @Test("Given inventory cache enabled, when snapshot follows skeleton load within TTL, then scan results are reused")
    func inventoryCacheReusesScanResultsAcrossSequentialLoads() throws {
        let root = try makeTempRoot("codex-session-store-inventory-cache-hit")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "thread-1",
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai",
            cwd: "/tmp/project-a"
        )

        let store = CodexSessionStore(
            defaultProviderID: "openai",
            enableInventoryCache: true,
            inventoryCacheTTL: 60
        )

        let skeleton = try store.loadProjectSkeletonSnapshot(codexHome: codexHome)
        #expect(skeleton.projects.count == 1)

        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "thread-2",
            timestamp: "2026-04-10T10:05:00Z",
            modelProvider: "openai",
            cwd: "/tmp/project-b"
        )

        let snapshot = try store.loadSnapshot(codexHome: codexHome)
        #expect(snapshot.sessions.count == 1)
        #expect(snapshot.sessions.map(\.threadID) == ["thread-1"])
    }

    @Test("Given inventory cache disabled, when snapshot follows skeleton load, then latest scan results are returned")
    func inventoryCacheCanBeDisabledForFreshScans() throws {
        let root = try makeTempRoot("codex-session-store-inventory-cache-miss")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "thread-1",
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai",
            cwd: "/tmp/project-a"
        )

        let store = CodexSessionStore(
            defaultProviderID: "openai",
            enableInventoryCache: false,
            inventoryCacheTTL: 60
        )

        let skeleton = try store.loadProjectSkeletonSnapshot(codexHome: codexHome)
        #expect(skeleton.projects.count == 1)

        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: "thread-2",
            timestamp: "2026-04-10T10:05:00Z",
            modelProvider: "openai",
            cwd: "/tmp/project-b"
        )

        let snapshot = try store.loadSnapshot(codexHome: codexHome)
        #expect(snapshot.sessions.count == 2)
        #expect(Set(snapshot.sessions.compactMap(\.threadID)) == Set(["thread-1", "thread-2"]))
    }

    @Test("Given multiple rollout files, when streaming snapshots, then each batch only yields delta sessions and the last event marks completion")
    func snapshotStreamYieldsDeltaEvents() async throws {
        let root = try makeTempRoot("codex-session-store-delta-stream")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadIDs = (0..<5).map { "thread-\($0)" }
        for (index, threadID) in threadIDs.enumerated() {
            _ = try writeRolloutSessionMeta(
                codexHome: codexHome,
                threadID: threadID,
                timestamp: "2026-04-10T1\(index):00:00Z",
                modelProvider: "openai",
                cwd: "/tmp/project-\(index < 3 ? "alpha" : "beta")"
            )
        }
        try createStateDatabase(
            codexHome: codexHome,
            threads: threadIDs.enumerated().map { index, threadID in
                (
                    id: threadID,
                    title: "Thread \(index)",
                    modelProvider: "openai",
                    updatedAt: Int64(1_000 + index),
                    archived: false
                )
            }
        )

        let stream = CodexSessionStore(defaultProviderID: "openai").snapshotStream(
            codexHome: codexHome,
            batchSize: 2
        )

        var events: [CodexSessionSnapshotDelta] = []
        for try await event in stream {
            events.append(event)
        }

        #expect(events.count == 3)
        #expect(events.map(\.sessions.count) == [2, 2, 1])
        #expect(events.dropLast().allSatisfy { !$0.isComplete })
        #expect(events.last?.isComplete == true)

        let streamedIDs = events.flatMap(\.sessions).map(\.id)
        #expect(Set(streamedIDs).count == 5)
        #expect(streamedIDs.count == 5)
    }

    @Test("Given session meta includes raw metadata, when loading snapshot, then store preserves forked from originator and source")
    func loadSnapshotPreservesRawMetadata() throws {
        let root = try makeTempRoot("codex-session-store-raw-metadata")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai",
            forkedFromID: "parent-thread-01",
            originator: "gemini-cli",
            source: "cli"
        )

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)
        let session = try #require(snapshot.sessions.first)

        #expect(session.forkedFromID == "parent-thread-01")
        #expect(session.originator == "gemini-cli")
        #expect(session.source == "cli")
    }

    @Test("Given state db omits title but session index contains thread name, when loading snapshot, then store uses the indexed thread name as fallback title")
    func loadSnapshotFallsBackToSessionIndexThreadNameForTitle() throws {
        let root = try makeTempRoot("codex-session-store-session-index-title")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "provider-one"
        )
        try writeSessionIndex(
            codexHome: codexHome,
            entries: [
                (id: threadID, threadName: "Indexed thread name", updatedAt: "2026-04-10T10:00:05Z")
            ]
        )
        try sqliteExecute(
            databaseURL: codexHome.file("state_1.sqlite").url,
            sql: """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                title TEXT,
                model_provider TEXT NOT NULL,
                updated_at INTEGER,
                archived INTEGER NOT NULL DEFAULT 0
            );
            """
        )
        try sqliteExecute(
            databaseURL: codexHome.file("state_1.sqlite").url,
            sql: """
            INSERT INTO threads (id, title, model_provider, updated_at, archived)
            VALUES (?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(threadID),
                .text("   "),
                .text("provider-one"),
                .int64(1_000),
                .int64(0),
            ]
        )

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)
        let session = try #require(snapshot.sessions.first)

        #expect(session.title == "Indexed thread name")
    }

    @Test("Given both state db title and session index thread name exist, when loading snapshot, then state db title still wins")
    func loadSnapshotPrefersStateTitleOverSessionIndexThreadName() throws {
        let root = try makeTempRoot("codex-session-store-state-title-preferred")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "provider-one"
        )
        try writeSessionIndex(
            codexHome: codexHome,
            entries: [
                (id: threadID, threadName: "Indexed thread name", updatedAt: "2026-04-10T10:00:05Z")
            ]
        )
        try createStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: threadID, title: "State title wins", modelProvider: "provider-one", updatedAt: 1_000, archived: false)
            ]
        )

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)
        let session = try #require(snapshot.sessions.first)

        #expect(session.title == "State title wins")
    }

    @Test("Given multiple state rows share one thread, when loading snapshot, then latest state row wins while row count still reflects all matches")
    func loadSnapshotUsesLatestStateRowForSharedThread() throws {
        let root = try makeTempRoot("codex-session-store-latest-state-row")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: nil
        )

        let databaseOneURL = codexHome.file("state_1.sqlite").url
        try sqliteExecute(
            databaseURL: databaseOneURL,
            sql: """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                title TEXT,
                model_provider TEXT NOT NULL,
                updated_at INTEGER,
                archived INTEGER NOT NULL DEFAULT 0
            );
            """
        )
        try sqliteExecute(
            databaseURL: databaseOneURL,
            sql: """
            INSERT INTO threads (id, title, model_provider, updated_at, archived)
            VALUES (?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(threadID),
                .text("Older title"),
                .text("provider-old"),
                .int64(1_000),
                .int64(0),
            ]
        )

        let databaseTwoURL = codexHome.file("state_2.sqlite").url
        try sqliteExecute(
            databaseURL: databaseTwoURL,
            sql: """
            CREATE TABLE threads (
                id TEXT PRIMARY KEY,
                title TEXT,
                model_provider TEXT NOT NULL,
                updated_at INTEGER,
                archived INTEGER NOT NULL DEFAULT 0
            );
            """
        )
        try sqliteExecute(
            databaseURL: databaseTwoURL,
            sql: """
            INSERT INTO threads (id, title, model_provider, updated_at, archived)
            VALUES (?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(threadID),
                .text("Latest title"),
                .text("provider-new"),
                .int64(2_000),
                .int64(0),
            ]
        )

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)
        let session = try #require(snapshot.sessions.first)

        #expect(session.title == "Latest title")
        #expect(session.modelProvider == "provider-new")
        #expect(session.stateRowCount == 2)
        #expect(session.updatedAt == Date(timeIntervalSince1970: 2_000))
    }

    @Test("Given rollout contains user content, when loading snapshot, then first screen record does not parse summary from rollout body")
    func loadSnapshotDoesNotReadSummaryFromRolloutBody() throws {
        let root = try makeTempRoot("codex-session-store-summary-skip")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai"
        )

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)
        let session = try #require(snapshot.sessions.first)

        #expect(session.threadID == threadID)
        #expect(session.summary == nil)
    }

    @Test("Given config exists but exposes no provider IDs, when loading snapshot, then store logs a warning and falls back to default provider")
    func loadSnapshotLogsWarningWhenConfigParsingFindsNoProviders() throws {
        let root = try makeTempRoot("codex-session-store-config-warning")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        try codexHome.file("config.toml").overlay(with: """
        # no model provider declarations here
        [experimental]
        enabled = true
        """)

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai"
        )

        let warningRecorder = WarningRecorder()
        let warningPaths = WarningRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.warningNotification,
            object: nil,
            queue: nil
        ) { notification in
            if let message = notification.userInfo?["message"] as? String {
                warningRecorder.append(message)
            }
            if let path = notification.userInfo?["codex_home_path"] as? String {
                warningPaths.append(path)
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)

        #expect(snapshot.availableProviderIDs == ["openai"])
        #expect(warningRecorder.messages.count == 1)
        #expect(warningRecorder.messages.first?.contains("config.toml") == true)
        #expect(warningPaths.messages == [codexHome.url.path])
    }

    @Test("Given snapshot load completes, when store publishes performance metrics, then elapsed time and counts are included")
    func loadSnapshotPublishesPerformanceMetrics() throws {
        let root = try makeTempRoot("codex-session-store-performance-load")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai"
        )

        let recorder = PerformanceRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.performanceNotification,
            object: nil,
            queue: nil
        ) { notification in
            recorder.append(notification.userInfo ?? [:])
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)

        #expect(snapshot.sessions.count == 1)
        let metrics = try #require(
            recorder.payloads.last(where: { payload in
                payload["operation"] as? String == "load_snapshot"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )
        #expect(metrics["operation"] as? String == "load_snapshot")
        #expect(metrics["session_count"] as? Int == 1)
        #expect(metrics["scanned_file_count"] as? Int == 1)
        #expect(metrics["codex_home_path"] as? String == codexHome.url.path)
        #expect((metrics["elapsed_ms"] as? Int ?? -1) >= 0)
        #expect((metrics["trace_id"] as? String)?.isEmpty == false)
    }

    @Test("Given one unreadable state sqlite, when loading snapshot, then store warns and skips the bad database")
    func loadSnapshotSkipsUnreadableStateDatabase() throws {
        let root = try makeTempRoot("codex-session-store-unreadable-state-db")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "openai"
        )
        try createStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: threadID, title: "Readable DB Title", modelProvider: "openai", updatedAt: 1_000, archived: false),
            ]
        )

        let unreadableDatabase = codexHome.file("state_bad.sqlite")
        try unreadableDatabase.overlay(with: "not-a-readable-sqlite")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadableDatabase.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: unreadableDatabase.path)
        }

        let warningRecorder = WarningRecorder()
        let warningObserver = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.warningNotification,
            object: nil,
            queue: nil
        ) { notification in
            if let message = notification.userInfo?["message"] as? String {
                warningRecorder.append(message)
            }
        }
        defer { NotificationCenter.default.removeObserver(warningObserver) }

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)

        #expect(snapshot.sessions.count == 1)
        #expect(snapshot.sessions.first?.title == "Readable DB Title")
        #expect(
            warningRecorder.messages.contains { message in
                message.contains("skipped unreadable state database")
                    && message.contains(unreadableDatabase.path)
            }
        )
    }

    @Test("Given rollout usage is loaded for the first time, when reading session usage, then store rebuilds from file and persists a usage index entry")
    func loadSessionUsageBuildsUsageIndexEntryOnFirstRead() throws {
        let root = try makeTempRoot("codex-session-usage-first-read")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":120,"cached_input_tokens":20,"output_tokens":30,"total_tokens":150}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let result = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )
        let entry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "sessions/usage.jsonl"
            )
        )

        #expect(result.source == .fullRebuild)
        #expect(result.totals == .init(inputTokens: 120, cachedInputTokens: 20, outputTokens: 30))
        #expect(entry.sessionID == "session-1")
        #expect(entry.parsedBytes > 0)
    }

    @Test("Given rollout usage is loaded for the first time, when reading minute usage rows, then store persists UTC minute buckets")
    func loadSessionUsageBuildsMinuteBucketsOnFirstRead() throws {
        let root = try makeTempRoot("codex-session-usage-minute-first-read")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":30,"total_tokens":130}}}}"#,
                #"{"timestamp":"2026-04-10T10:00:50Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":120,"cached_input_tokens":25,"output_tokens":35,"total_tokens":155}}}}"#,
                #"{"timestamp":"2026-04-10T10:01:03Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":3,"cached_input_tokens":1,"output_tokens":2,"total_tokens":5}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )
        let expectedMinute0 = try parseISO8601("2026-04-10T10:00:00Z")
        let expectedMinute1 = try parseISO8601("2026-04-10T10:01:00Z")
        let minuteRows = try store.loadSessionUsageMinuteEntries(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )

        #expect(minuteRows.count == 2)
        #expect(minuteRows[0].sessionID == "session-1")
        #expect(minuteRows[0].minuteStartAt == expectedMinute0)
        #expect(minuteRows[0].inputTokens == 120)
        #expect(minuteRows[0].cachedInputTokens == 25)
        #expect(minuteRows[0].outputTokens == 35)
        #expect(minuteRows[1].minuteStartAt == expectedMinute1)
        #expect(minuteRows[1].inputTokens == 3)
        #expect(minuteRows[1].cachedInputTokens == 1)
        #expect(minuteRows[1].outputTokens == 2)
    }

    @Test("Given rollout contains a huge response item line, when loading session usage, then timeline still uses the top-level timestamps")
    func loadSessionUsageKeepsTimelineForHugeResponseItemLine() throws {
        let root = try makeTempRoot("codex-session-usage-huge-response-item")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let hugeOutput = String(repeating: "A", count: 2_000_000)
        _ = try writeUsageRollout(
            codexHome: codexHome,
            usageLines: [
                """
                {"timestamp":"2026-04-10T10:00:02Z","type":"response_item","payload":{"type":"function_call_output","call_id":"call_1","output":"\(hugeOutput)"}}
                """,
                #"{"timestamp":"2026-04-10T10:00:03Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":120,"cached_input_tokens":20,"output_tokens":30,"total_tokens":150}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let result = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )
        let expectedStartedAt = try parseISO8601("2026-04-10T10:00:00Z")
        let expectedLastActivityAt = try parseISO8601("2026-04-10T10:00:03Z")

        #expect(result.totals == .init(inputTokens: 120, cachedInputTokens: 20, outputTokens: 30))
        #expect(result.timeline?.startedAt == expectedStartedAt)
        #expect(result.timeline?.lastActivityAt == expectedLastActivityAt)
    }

    @Test("Given rollout usage index matches the current file, when reading session usage again, then store returns a cache hit")
    func loadSessionUsageReturnsCacheHitWhenFileIsUnchanged() throws {
        let root = try makeTempRoot("codex-session-usage-cache-hit")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":90,"cached_input_tokens":10,"output_tokens":15,"total_tokens":105}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsageRecord(codexHome: codexHome.url, rolloutPath: "sessions/usage.jsonl")
        let second = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )

        #expect(second.source == .cacheHit)
        #expect(second.totals == .init(inputTokens: 90, cachedInputTokens: 10, outputTokens: 15))
    }

    @Test("Given archived rollout usage already has a content hash, when only file metadata changes, then store reuses the archived cache entry")
    func loadSessionUsageReturnsCacheHitForArchivedRolloutWhenOnlyMetadataChanges() throws {
        let root = try makeTempRoot("codex-session-usage-archived-hash-hit")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let file = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/frozen.jsonl",
            sessionID: "session-archived",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":90,"cached_input_tokens":10,"output_tokens":15,"total_tokens":105}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let first = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "archived_sessions/frozen.jsonl"
        )
        let firstEntry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "archived_sessions/frozen.jsonl"
            )
        )

        let touchedDate = try parseISO8601("2026-04-10T11:00:00Z")
        try FileManager.default.setAttributes(
            [.modificationDate: touchedDate],
            ofItemAtPath: file.path
        )

        let second = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "archived_sessions/frozen.jsonl"
        )
        let secondEntry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "archived_sessions/frozen.jsonl"
            )
        )

        #expect(first.source == .fullRebuild)
        #expect(firstEntry.isArchived)
        #expect(firstEntry.contentHash != nil)
        #expect(second.source == .cacheHit)
        #expect(second.totals == .init(inputTokens: 90, cachedInputTokens: 10, outputTokens: 15))
        #expect(secondEntry.contentHash == firstEntry.contentHash)
        #expect(secondEntry.modifiedAtUnixMs == firstEntry.modifiedAtUnixMs)
        #expect(secondEntry.lastRequestedAtUnixMs >= firstEntry.lastRequestedAtUnixMs)
    }

    @Test("Given rollout usage cache entry exists but minute buckets were removed, when reading session usage again, then store rebuilds and restores minute rows")
    func loadSessionUsageBackfillsMissingMinuteBucketsOnCacheHit() throws {
        let root = try makeTempRoot("codex-session-usage-backfill-minutes")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/backfill.jsonl",
            sessionID: "session-backfill",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}"#,
                #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":140,"cached_input_tokens":20,"output_tokens":30,"total_tokens":170}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/backfill.jsonl"
        )

        let usageIndexDatabaseURL = cacheRoot.url.appendingPathComponent("usage-index-v1.sqlite")
        try sqliteExecute(
            databaseURL: usageIndexDatabaseURL,
            sql: """
            DELETE FROM session_usage_minutes
            WHERE codex_home_path = ? AND rollout_path = ?;
            """,
            bindings: [
                .text(codexHome.path),
                .text("sessions/backfill.jsonl"),
            ]
        )

        let second = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/backfill.jsonl"
        )

        #expect(second.source == .fullRebuild)
        #expect(second.totals == .init(inputTokens: 140, cachedInputTokens: 20, outputTokens: 30))

        let minuteRows = try store.loadSessionUsageMinuteEntries(
            codexHome: codexHome.url,
            rolloutPath: "sessions/backfill.jsonl"
        )

        #expect(minuteRows.count == 2)
        #expect(minuteRows[0].inputTokens == 100)
        #expect(minuteRows[0].cachedInputTokens == 10)
        #expect(minuteRows[0].outputTokens == 20)
        #expect(minuteRows[1].inputTokens == 40)
        #expect(minuteRows[1].cachedInputTokens == 10)
        #expect(minuteRows[1].outputTokens == 10)
    }

    @Test("Given rollout usage cache still has token minute buckets but legacy request counts are zero, when reading session usage again, then store rebuilds and restores request counts")
    func loadSessionUsageBackfillsMissingRequestCountsOnCacheHit() throws {
        let root = try makeTempRoot("codex-session-usage-backfill-requests")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/backfill-requests.jsonl",
            sessionID: "session-backfill-requests",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}"#,
                #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":140,"cached_input_tokens":20,"output_tokens":30,"total_tokens":170}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/backfill-requests.jsonl"
        )

        let initialMinuteRows = try store.loadSessionUsageMinuteEntries(
            codexHome: codexHome.url,
            rolloutPath: "sessions/backfill-requests.jsonl"
        )
        #expect(initialMinuteRows.map(\.requestCount) == [1, 1])

        let usageIndexDatabaseURL = cacheRoot.url.appendingPathComponent("usage-index-v1.sqlite")
        try sqliteExecute(
            databaseURL: usageIndexDatabaseURL,
            sql: """
            UPDATE session_usage_minutes
            SET request_count = 0
            WHERE codex_home_path = ? AND rollout_path = ?;
            """,
            bindings: [
                .text(codexHome.path),
                .text("sessions/backfill-requests.jsonl"),
            ]
        )

        let second = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/backfill-requests.jsonl"
        )

        #expect(second.source == .fullRebuild)

        let repairedMinuteRows = try store.loadSessionUsageMinuteEntries(
            codexHome: codexHome.url,
            rolloutPath: "sessions/backfill-requests.jsonl"
        )

        #expect(repairedMinuteRows.count == 2)
        #expect(repairedMinuteRows.map(\.requestCount) == [1, 1])
        #expect(repairedMinuteRows[0].inputTokens == 100)
        #expect(repairedMinuteRows[1].inputTokens == 40)
    }

    @Test("Given rollout usage file appends new token lines, when reading session usage again, then store only parses the appended tail and merges totals")
    func loadSessionUsageMergesAppendedTailDelta() throws {
        let root = try makeTempRoot("codex-session-usage-append")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let file = try writeUsageRollout(
            codexHome: codexHome,
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":30,"output_tokens":25,"total_tokens":125}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let first = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )
        try appendRolloutLines(file: file, lines: [
            #"{"timestamp":"2026-04-10T10:00:03Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":107,"cached_input_tokens":33,"output_tokens":29,"total_tokens":136}}}}"#,
        ])

        let second = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )

        #expect(first.source == .fullRebuild)
        #expect(second.source == .deltaAppend)
        #expect(second.totals == .init(inputTokens: 107, cachedInputTokens: 33, outputTokens: 29))
    }

    @Test("Given rollout usage cache has legacy zero request counts and the file grows, when reading session usage again, then store does a full rebuild instead of delta append")
    func loadSessionUsagePrefersFullRebuildOverDeltaAppendWhenRequestCountsNeedBackfill() throws {
        let root = try makeTempRoot("codex-session-usage-append-request-backfill")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let file = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/append-request-backfill.jsonl",
            sessionID: "session-append-request-backfill",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/append-request-backfill.jsonl"
        )

        let usageIndexDatabaseURL = cacheRoot.url.appendingPathComponent("usage-index-v1.sqlite")
        try sqliteExecute(
            databaseURL: usageIndexDatabaseURL,
            sql: """
            UPDATE session_usage_minutes
            SET request_count = 0
            WHERE codex_home_path = ? AND rollout_path = ?;
            """,
            bindings: [
                .text(codexHome.path),
                .text("sessions/append-request-backfill.jsonl"),
            ]
        )

        try appendRolloutLines(file: file, lines: [
            #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":140,"cached_input_tokens":20,"output_tokens":30,"total_tokens":170}}}}"#,
        ])

        let second = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/append-request-backfill.jsonl"
        )

        #expect(second.source == .fullRebuild)

        let repairedMinuteRows = try store.loadSessionUsageMinuteEntries(
            codexHome: codexHome.url,
            rolloutPath: "sessions/append-request-backfill.jsonl"
        )

        #expect(repairedMinuteRows.count == 2)
        #expect(repairedMinuteRows.map(\.requestCount) == [1, 1])
        #expect(repairedMinuteRows[0].inputTokens == 100)
        #expect(repairedMinuteRows[1].inputTokens == 40)
    }

    @Test("Given rollout usage file appends new token lines, when reading minute usage rows again, then store only merges affected UTC minute buckets")
    func loadSessionUsageAppendsOnlyNewMinuteBucketsForTailDelta() throws {
        let root = try makeTempRoot("codex-session-minute-append")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let file = try writeUsageRollout(
            codexHome: codexHome,
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":30,"output_tokens":25,"total_tokens":125}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )

        try appendRolloutLines(file: file, lines: [
            #"{"timestamp":"2026-04-10T10:00:55Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":106,"cached_input_tokens":31,"output_tokens":30,"total_tokens":136}}}}"#,
            #"{"timestamp":"2026-04-10T10:01:10Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":110,"cached_input_tokens":33,"output_tokens":32,"total_tokens":142}}}}"#,
        ])

        let second = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )
        let expectedMinute0 = try parseISO8601("2026-04-10T10:00:00Z")
        let expectedMinute1 = try parseISO8601("2026-04-10T10:01:00Z")
        let minuteRows = try store.loadSessionUsageMinuteEntries(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )

        #expect(second.source == .deltaAppend)
        #expect(minuteRows.count == 2)
        #expect(minuteRows[0].minuteStartAt == expectedMinute0)
        #expect(minuteRows[0].inputTokens == 106)
        #expect(minuteRows[0].cachedInputTokens == 31)
        #expect(minuteRows[0].outputTokens == 30)
        #expect(minuteRows[1].minuteStartAt == expectedMinute1)
        #expect(minuteRows[1].inputTokens == 4)
        #expect(minuteRows[1].cachedInputTokens == 2)
        #expect(minuteRows[1].outputTokens == 2)
    }

    @Test("Given a forked rollout inherits parent cumulative totals, when loading projected usage summary, then only post-fork usage is counted")
    func loadProjectedUsageSummaryCountsOnlyPostForkUsageForDerivedRollout() throws {
        let root = try makeTempRoot("codex-session-derived-summary")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/parent.jsonl",
            sessionID: "parent-session",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}"#,
            ]
        )
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/derived.jsonl",
            sessionID: "child-session",
            preludeLines: try [
                makeSessionMetaLine(
                    sessionID: "child-session",
                    forkedFromID: "parent-session",
                    source: [
                        "type": "thread_spawn",
                        "parent_id": "parent-session",
                    ]
                ),
                makeSessionMetaLine(
                    sessionID: "parent-session",
                    timestamp: "2026-04-10T10:00:00.100Z"
                ),
                #"{"timestamp":"2026-04-10T10:00:01Z","type":"turn_context","payload":{"model":"gpt-5"}}"#,
            ],
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:40Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":80,"cached_input_tokens":8,"output_tokens":10,"total_tokens":90}}}}"#,
                #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":95,"cached_input_tokens":9,"output_tokens":14,"total_tokens":109}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let summary = try store.loadProjectedUsageSummary(codexHome: codexHome.url)
        let requiredSummary = try #require(summary)

        #expect(requiredSummary.totalTokens == 139)
        #expect(requiredSummary.sourceLabel == "global local usage")
    }

    @Test("Given a forked rollout appends more cumulative usage, when loading the usage record again, then store rebuilds from scratch and keeps only post-fork totals")
    func loadSessionUsageRecordRebuildsForkedRolloutToPreserveDerivedTotals() throws {
        let root = try makeTempRoot("codex-session-derived-rebuild")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let file = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/derived.jsonl",
            sessionID: "child-session",
            preludeLines: try [
                makeSessionMetaLine(
                    sessionID: "child-session",
                    forkedFromID: "parent-session",
                    source: [
                        "type": "thread_spawn",
                        "parent_id": "parent-session",
                    ]
                ),
                makeSessionMetaLine(
                    sessionID: "parent-session",
                    timestamp: "2026-04-10T10:00:00.100Z"
                ),
                #"{"timestamp":"2026-04-10T10:00:01Z","type":"turn_context","payload":{"model":"gpt-5"}}"#,
            ],
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:40Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":80,"cached_input_tokens":8,"output_tokens":10,"total_tokens":90}}}}"#,
                #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":95,"cached_input_tokens":9,"output_tokens":14,"total_tokens":109}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let first = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/derived.jsonl"
        )
        #expect(first.source == .fullRebuild)
        #expect(first.totals == .init(inputTokens: 15, cachedInputTokens: 1, outputTokens: 4))

        try appendRolloutLines(file: file, lines: [
            #"{"timestamp":"2026-04-10T10:02:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":110,"cached_input_tokens":10,"output_tokens":18,"total_tokens":128}}}}"#,
        ])

        let second = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/derived.jsonl"
        )
        let minuteRows = try store.loadSessionUsageMinuteEntries(
            codexHome: codexHome.url,
            rolloutPath: "sessions/derived.jsonl"
        )

        #expect(second.source == .fullRebuild)
        #expect(second.totals == .init(inputTokens: 30, cachedInputTokens: 2, outputTokens: 8))
        #expect(minuteRows.count == 2)
        #expect(minuteRows[0].inputTokens == 15)
        #expect(minuteRows[0].cachedInputTokens == 1)
        #expect(minuteRows[0].outputTokens == 4)
        #expect(minuteRows[1].inputTokens == 15)
        #expect(minuteRows[1].cachedInputTokens == 1)
        #expect(minuteRows[1].outputTokens == 4)
    }

    @Test("Given rollout usage file is replaced with a smaller payload, when reading session usage again, then store falls back to a full rebuild")
    func loadSessionUsageFallsBackToFullRebuildWhenFileIsReplaced() throws {
        let root = try makeTempRoot("codex-session-usage-replace")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let file = try writeUsageRollout(
            codexHome: codexHome,
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":300,"cached_input_tokens":50,"output_tokens":40,"total_tokens":340}}}}"#,
                #"{"timestamp":"2026-04-10T10:00:03Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"cached_input_tokens":5,"output_tokens":2,"total_tokens":12}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsageRecord(codexHome: codexHome.url, rolloutPath: "sessions/usage.jsonl")
        try file.overlay(with: """
        {"timestamp":"2026-04-10T10:00:00Z","type":"session_meta","payload":{"id":"session-1"}}
        {"timestamp":"2026-04-10T10:00:01Z","type":"turn_context","payload":{"model":"gpt-5"}}
        {"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":80,"cached_input_tokens":8,"output_tokens":9,"total_tokens":89}}}}
        """)

        let rebuilt = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )

        #expect(rebuilt.source == .fullRebuild)
        #expect(rebuilt.totals == .init(inputTokens: 80, cachedInputTokens: 8, outputTokens: 9))
    }

    @Test("Given rollout usage file is replaced, when reading minute usage rows again, then store removes stale UTC minute buckets before full rebuild")
    func loadSessionUsageFullRebuildReplacesStaleMinuteBuckets() throws {
        let root = try makeTempRoot("codex-session-minute-rebuild")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let file = try writeUsageRollout(
            codexHome: codexHome,
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":80,"cached_input_tokens":8,"output_tokens":9,"total_tokens":89}}}}"#,
                #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":4,"cached_input_tokens":1,"output_tokens":2,"total_tokens":6}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )
        try file.overlay(with: """
        {"timestamp":"2026-04-10T10:00:00Z","type":"session_meta","payload":{"id":"session-1"}}
        {"timestamp":"2026-04-10T10:00:01Z","type":"turn_context","payload":{"model":"gpt-5"}}
        {"timestamp":"2026-04-10T11:05:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":30,"cached_input_tokens":3,"output_tokens":4,"total_tokens":34}}}}
        """)

        let rebuilt = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )
        let expectedMinute = try parseISO8601("2026-04-10T11:05:00Z")
        let minuteRows = try store.loadSessionUsageMinuteEntries(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )

        #expect(rebuilt.source == .fullRebuild)
        #expect(minuteRows.count == 1)
        #expect(minuteRows[0].minuteStartAt == expectedMinute)
        #expect(minuteRows[0].inputTokens == 30)
        #expect(minuteRows[0].cachedInputTokens == 3)
        #expect(minuteRows[0].outputTokens == 4)
    }

    @Test("Given rollout usage file disappears after being indexed, when reading session usage again, then store returns nil and removes the usage index entry")
    func loadSessionUsageRemovesUsageIndexEntryWhenFileDisappears() throws {
        let root = try makeTempRoot("codex-session-usage-delete")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let file = try writeUsageRollout(
            codexHome: codexHome,
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":50,"cached_input_tokens":5,"output_tokens":7,"total_tokens":57}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsageRecord(codexHome: codexHome.url, rolloutPath: "sessions/usage.jsonl")
        try file.delete()

        let missing = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )
        let entry = try store.loadUsageIndexEntry(
            codexHome: codexHome.url,
            rolloutPath: "sessions/usage.jsonl"
        )

        #expect(missing.source == .fileMissing)
        #expect(missing.totals == nil)
        #expect(entry == nil)
    }

    @Test("Given rollout contains parseable timestamps, when loading session timeline, then store returns the first and last event timestamps")
    func loadSessionTimelineReturnsFirstAndLastTimestamp() throws {
        let root = try makeTempRoot("codex-session-timeline-range")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/timeline.jsonl",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:05Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":2,"total_tokens":12}}}}"#,
                #"{"timestamp":"2026-04-10T10:02:30Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"done"}]}}"#,
            ]
        )
        let store = CodexSessionStore()

        let timeline = try #require(
            try store.loadSessionTimeline(
                codexHome: codexHome.url,
                rolloutPath: "sessions/timeline.jsonl"
            )
        )
        let expectedStartedAt = try parseISO8601("2026-04-10T10:00:00Z")
        let expectedLastActivityAt = try parseISO8601("2026-04-10T10:02:30Z")

        #expect(timeline.startedAt == expectedStartedAt)
        #expect(timeline.lastActivityAt == expectedLastActivityAt)
    }

    @Test("Given rollout usage was indexed and file is unchanged, when loading session timeline, then store reuses cached timeline metadata")
    func loadSessionTimelineReturnsCacheHitWhenIndexedMetadataIsFresh() throws {
        let root = try makeTempRoot("codex-session-timeline-cache-hit")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/timeline-cache.jsonl",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:05Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":2,"total_tokens":12}}}}"#,
                #"{"timestamp":"2026-04-10T10:02:30Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"done"}]}}"#,
            ]
        )
        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let usage = try store.loadSessionUsageRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/timeline-cache.jsonl"
        )
        let entry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "sessions/timeline-cache.jsonl"
            )
        )
        let timeline = try store.loadSessionTimelineRecord(
            codexHome: codexHome.url,
            rolloutPath: "sessions/timeline-cache.jsonl"
        )

        #expect(usage.source == .fullRebuild)
        #expect(entry.startedAtUnixMs != nil)
        #expect(entry.lastActivityAtUnixMs != nil)
        #expect(timeline.source == .cacheHit)
        #expect(
            timeline.timeline?.startedAt
                == entry.startedAtUnixMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1_000) }
        )
        #expect(
            timeline.timeline?.lastActivityAt
                == entry.lastActivityAtUnixMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1_000) }
        )
    }

    @Test("Given rollout has no parseable timestamps, when loading session timeline, then store leaves startedAt empty and falls back lastActivityAt to file metadata")
    func loadSessionTimelineFallsBackToFileMetadataWhenTimestampsAreMissing() throws {
        let root = try makeTempRoot("codex-session-timeline-fallback")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let file = codexHome.file("sessions/invalid-timeline.jsonl")
        _ = file.parentFolder()?.createIfNotExists()
        try file.overlay(with: """
        {"timestamp":"not-a-date","type":"session_meta","payload":{"id":"session-1"}}
        {"timestamp":"still-not-a-date","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"done"}]}}
        """)
        let expectedLastActivityAt = try parseISO8601("2026-04-10T11:23:45Z")
        try FileManager.default.setAttributes(
            [.modificationDate: expectedLastActivityAt],
            ofItemAtPath: file.path
        )
        let store = CodexSessionStore()

        let timeline = try #require(
            try store.loadSessionTimeline(
                codexHome: codexHome.url,
                rolloutPath: "sessions/invalid-timeline.jsonl"
            )
        )

        #expect(timeline.startedAt == nil)
        #expect(timeline.lastActivityAt == expectedLastActivityAt)
    }

    @Test("Given duplicate rollout files share the same session id, when projecting global minute usage, then store keeps only the canonical source contribution")
    func loadProjectedUsageMinutesDeduplicatesCanonicalSessionSource() throws {
        let root = try makeTempRoot("codex-session-minute-projection")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/primary.jsonl",
            sessionID: "session-1",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}"#,
            ]
        )
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/duplicate.jsonl",
            sessionID: "session-1",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":60,"cached_input_tokens":6,"output_tokens":12,"total_tokens":72}}}}"#,
            ]
        )
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/other.jsonl",
            sessionID: "session-2",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20,"cached_input_tokens":2,"output_tokens":5,"total_tokens":25}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let expectedMinute0 = try parseISO8601("2026-04-10T10:00:00Z")
        let expectedMinute1 = try parseISO8601("2026-04-10T10:01:00Z")
        let projected = try store.loadProjectedUsageMinutes(
            codexHome: codexHome.url
        )

        #expect(projected.entries.count == 2)
        #expect(projected.entries[0].minuteStartAt == expectedMinute0)
        #expect(projected.entries[0].inputTokens == 100)
        #expect(projected.entries[0].cachedInputTokens == 10)
        #expect(projected.entries[0].outputTokens == 20)
        #expect(projected.entries[1].minuteStartAt == expectedMinute1)
        #expect(projected.entries[1].inputTokens == 20)
        #expect(projected.entries[1].cachedInputTokens == 2)
        #expect(projected.entries[1].outputTokens == 5)
    }

    @Test("Given projected usage index is built from scratch, when loading projected usage minutes, then store publishes per-rollout progress notifications")
    func loadProjectedUsageMinutesPublishesInitialBuildProgressMetrics() throws {
        let root = try makeTempRoot("codex-session-minute-projection-progress")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/live-a.jsonl",
            sessionID: "session-live-a",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}"#,
            ]
        )
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/archive-b.jsonl",
            sessionID: "session-archive-b",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20,"cached_input_tokens":2,"output_tokens":5,"total_tokens":25}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )
        let recorder = PerformanceRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.performanceNotification,
            object: nil,
            queue: nil
        ) { notification in
            recorder.append(notification.userInfo ?? [:])
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let projected = try store.loadProjectedUsageMinutes(codexHome: codexHome.url)

        let startedMetrics = try #require(
            recorder.payloads.first(where: { payload in
                payload["operation"] as? String == "prepare_projected_usage_index"
                    && payload["phase"] as? String == "started"
                    && payload["detail_phase"] as? String == "reconcile_rollouts"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )
        let analyzeMetrics = try #require(
            recorder.payloads.first(where: { payload in
                payload["operation"] as? String == "prepare_projected_usage_index"
                    && payload["phase"] as? String == "progress"
                    && payload["detail_phase"] as? String == "analyze_rollout"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )
        let progressMetrics = recorder.payloads.filter { payload in
            payload["operation"] as? String == "prepare_projected_usage_index"
                && payload["phase"] as? String == "progress"
                && payload["detail_phase"] as? String == "rollout_completed"
                && payload["codex_home_path"] as? String == codexHome.url.path
        }
        let finishedMetrics = try #require(
            recorder.payloads.last(where: { payload in
                payload["operation"] as? String == "prepare_projected_usage_index"
                    && payload["phase"] as? String == "completed"
                    && payload["detail_phase"] as? String == "finished"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )

        #expect(projected.entries.count == 2)
        #expect(startedMetrics["dirty_rollout_count"] as? Int == 2)
        #expect(startedMetrics["scanned_file_count"] as? Int == 2)
        #expect(startedMetrics["cached_entry_count"] as? Int == 0)
        let analyzedRolloutPath = analyzeMetrics["current_rollout_path"] as? String
        let completedRolloutPaths = Set(progressMetrics.compactMap { payload in
            payload["current_rollout_path"] as? String
        })
        let processedCounts = Set(progressMetrics.compactMap { payload in
            payload["processed_rollout_count"] as? Int
        })
        let finalProgressMetrics = try #require(
            progressMetrics.first(where: { payload in
                payload["processed_rollout_count"] as? Int == 2
            })
        )

        #expect(
            analyzedRolloutPath == "sessions/live-a.jsonl"
                || analyzedRolloutPath == "archived_sessions/archive-b.jsonl"
        )
        #expect(progressMetrics.count == 2)
        #expect(completedRolloutPaths == Set(["sessions/live-a.jsonl", "archived_sessions/archive-b.jsonl"]))
        #expect(processedCounts == Set([1, 2]))
        #expect(finalProgressMetrics["refreshed_live_rollout_count"] as? Int == 1)
        #expect(finalProgressMetrics["refreshed_archived_rollout_count"] as? Int == 1)
        #expect(finishedMetrics["cached_entry_count"] as? Int == 2)
        #expect((finishedMetrics["elapsed_ms"] as? Int ?? -1) >= 0)
    }

    @Test("Given projected usage includes archived rollouts, when only archived file metadata changes, then projection reuses the archived cache entry")
    func loadProjectedUsageMinutesReusesArchivedCacheEntryWhenOnlyMetadataChanges() throws {
        let root = try makeTempRoot("codex-session-minute-projection-archived-hash-hit")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        let archivedFile = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/frozen.jsonl",
            sessionID: "session-archived",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":90,"cached_input_tokens":10,"output_tokens":15,"total_tokens":105}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let firstProjection = try store.loadProjectedUsageMinutes(codexHome: codexHome.url)
        let firstEntry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "archived_sessions/frozen.jsonl"
            )
        )

        let touchedDate = try parseISO8601("2026-04-10T11:00:00Z")
        try FileManager.default.setAttributes(
            [.modificationDate: touchedDate],
            ofItemAtPath: archivedFile.path
        )

        let secondProjection = try store.loadProjectedUsageMinutes(codexHome: codexHome.url)
        let secondEntry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "archived_sessions/frozen.jsonl"
            )
        )

        #expect(firstProjection.entries == secondProjection.entries)
        #expect(firstEntry.isArchived)
        #expect(firstEntry.contentHash != nil)
        #expect(secondEntry.contentHash == firstEntry.contentHash)
        #expect(secondEntry.modifiedAtUnixMs == firstEntry.modifiedAtUnixMs)
        #expect(secondEntry.lastRequestedAtUnixMs >= firstEntry.lastRequestedAtUnixMs)
    }

    @Test("Given one live rollout changes and another remains unchanged, when refreshing projected usage day keys, then only the dirty rollout is reread")
    func refreshChangedProjectedUsageDayKeysTouchesOnlyDirtyRollouts() throws {
        let root = try makeTempRoot("codex-session-projection-dirty-rollouts")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/unchanged.jsonl",
            sessionID: "session-unchanged",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":50,"cached_input_tokens":5,"output_tokens":8,"total_tokens":58}}}}"#,
            ]
        )
        let changedFile = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/changed.jsonl",
            sessionID: "session-changed",
            usageLines: [
                #"{"timestamp":"2026-04-21T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":90,"cached_input_tokens":9,"output_tokens":15,"total_tokens":105}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )
        let recorder = PerformanceRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.performanceNotification,
            object: nil,
            queue: nil
        ) { notification in
            recorder.append(notification.userInfo ?? [:])
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        _ = try store.loadProjectedUsageMinutes(codexHome: codexHome.url)
        let unchangedBefore = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "archived_sessions/unchanged.jsonl"
            )
        )
        let changedBefore = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "sessions/changed.jsonl"
            )
        )

        try appendRolloutLines(file: changedFile, lines: [
            #"{"timestamp":"2026-04-21T10:05:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":120,"cached_input_tokens":12,"output_tokens":21,"total_tokens":141}}}}"#,
        ])
        try FileManager.default.setAttributes(
            [.modificationDate: try parseISO8601("2026-04-21T10:05:02Z")],
            ofItemAtPath: changedFile.path
        )

        let affectedDayKeys = try store.refreshChangedProjectedUsageDayKeys(
            codexHome: codexHome.url,
            timezone: .current
        )
        let unchangedAfter = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "archived_sessions/unchanged.jsonl"
            )
        )
        let changedAfter = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "sessions/changed.jsonl"
            )
        )

        #expect(affectedDayKeys == ["2026-04-21"])
        #expect(unchangedAfter.lastRequestedAtUnixMs == unchangedBefore.lastRequestedAtUnixMs)
        #expect(changedAfter.lastRequestedAtUnixMs >= changedBefore.lastRequestedAtUnixMs)
        let startedMetrics = try #require(
            recorder.payloads.first(where: { payload in
                payload["operation"] as? String == "refresh_projected_usage_day_keys"
                    && payload["phase"] as? String == "started"
                    && payload["detail_phase"] as? String == "reconcile_rollouts"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )
        let progressMetrics = try #require(
            recorder.payloads.first(where: { payload in
                payload["operation"] as? String == "refresh_projected_usage_day_keys"
                    && payload["phase"] as? String == "progress"
                    && payload["detail_phase"] as? String == "rollout_completed"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )
        let metrics = try #require(
            recorder.payloads.last(where: { payload in
                payload["operation"] as? String == "refresh_projected_usage_day_keys"
                    && payload["phase"] as? String == "completed"
                    && payload["detail_phase"] as? String == "finished"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )
        let readIndexMetrics = try #require(
            recorder.payloads.first(where: { payload in
                payload["operation"] as? String == "refresh_projected_usage_day_keys"
                    && payload["phase"] as? String == "started"
                    && payload["detail_phase"] as? String == "read_usage_index"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )
        let analyzeRolloutMetrics = try #require(
            recorder.payloads.first(where: { payload in
                payload["operation"] as? String == "refresh_projected_usage_day_keys"
                    && payload["phase"] as? String == "progress"
                    && payload["detail_phase"] as? String == "analyze_rollout"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )
        #expect(startedMetrics["dirty_rollout_count"] as? Int == 1)
        #expect(startedMetrics["skipped_rollout_count"] as? Int == 1)
        #expect(readIndexMetrics["current_database_name"] as? String == "usage-index-v1.sqlite")
        #expect(progressMetrics["processed_rollout_count"] as? Int == 1)
        #expect(progressMetrics["dirty_rollout_count"] as? Int == 1)
        #expect(progressMetrics["current_refresh_reason"] as? String == "live_fingerprint_changed")
        #expect(progressMetrics["current_rollout_path"] as? String == "sessions/changed.jsonl")
        #expect(analyzeRolloutMetrics["current_database_name"] as? String == "usage-index-v1.sqlite")
        #expect(metrics["scanned_file_count"] as? Int == 2)
        #expect(metrics["cached_entry_count"] as? Int == 2)
        #expect(metrics["refreshed_live_rollout_count"] as? Int == 1)
        #expect(metrics["refreshed_archived_rollout_count"] as? Int == 0)
        #expect(metrics["removed_rollout_count"] as? Int == 0)
        #expect(metrics["new_rollout_count"] as? Int == 0)
        #expect(metrics["live_fingerprint_changed_count"] as? Int == 1)
        #expect(metrics["archived_hash_missing_count"] as? Int == 0)
        #expect(metrics["archived_state_changed_count"] as? Int == 0)
        #expect(metrics["fingerprint_unavailable_count"] as? Int == 0)
        #expect(metrics["skipped_rollout_count"] as? Int == 1)
        #expect(metrics["affected_day_key_count"] as? Int == 1)
        #expect(metrics["timezone_identifier"] as? String == TimeZone.current.identifier)
        #expect((metrics["elapsed_ms"] as? Int ?? -1) >= 0)
    }

    @Test("Given a new rollout appears after the initial index build, when refreshing projected usage day keys, then metrics classify it as a new rollout")
    func refreshChangedProjectedUsageDayKeysClassifiesNewRolloutReason() throws {
        let root = try makeTempRoot("codex-session-projection-new-rollout")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/existing.jsonl",
            sessionID: "session-existing",
            usageLines: [
                #"{"timestamp":"2026-04-20T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":40,"cached_input_tokens":4,"output_tokens":6,"total_tokens":46}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url,
            inventoryCacheTTL: 0
        )
        let recorder = PerformanceRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.performanceNotification,
            object: nil,
            queue: nil
        ) { notification in
            recorder.append(notification.userInfo ?? [:])
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        _ = try store.loadProjectedUsageMinutes(codexHome: codexHome.url)
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/new.jsonl",
            sessionID: "session-new",
            usageLines: [
                #"{"timestamp":"2026-04-21T11:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":80,"cached_input_tokens":8,"output_tokens":12,"total_tokens":92}}}}"#,
            ]
        )

        let affectedDayKeys = try store.refreshChangedProjectedUsageDayKeys(
            codexHome: codexHome.url,
            timezone: .current
        )
        let newEntry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "sessions/new.jsonl"
            )
        )
        let metrics = try #require(
            recorder.payloads.last(where: { payload in
                payload["operation"] as? String == "refresh_projected_usage_day_keys"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )

        #expect(affectedDayKeys == ["2026-04-21"])
        #expect(newEntry.lastRequestedAtUnixMs > 0)
        #expect(metrics["scanned_file_count"] as? Int == 2)
        #expect(metrics["cached_entry_count"] as? Int == 1)
        #expect(metrics["new_rollout_count"] as? Int == 1)
        #expect(metrics["refreshed_live_rollout_count"] as? Int == 1)
        #expect(metrics["refreshed_archived_rollout_count"] as? Int == 0)
        #expect(metrics["live_fingerprint_changed_count"] as? Int == 0)
        #expect(metrics["archived_hash_missing_count"] as? Int == 0)
        #expect(metrics["archived_state_changed_count"] as? Int == 0)
        #expect(metrics["fingerprint_unavailable_count"] as? Int == 0)
        #expect(metrics["skipped_rollout_count"] as? Int == 1)
    }

    @Test("Given scanned files were cached moments ago, when a new rollout appears before TTL expires, then refresh still detects the new rollout")
    func refreshChangedProjectedUsageDayKeysBypassesInventoryCacheForNewRollouts() throws {
        let root = try makeTempRoot("codex-session-projection-new-rollout-cache-bypass")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/existing.jsonl",
            sessionID: "session-existing",
            usageLines: [
                #"{"timestamp":"2026-04-20T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":40,"cached_input_tokens":4,"output_tokens":6,"total_tokens":46}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadProjectedUsageMinutes(codexHome: codexHome.url)
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/new-live.jsonl",
            sessionID: "session-new-live",
            usageLines: [
                #"{"timestamp":"2026-04-21T11:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":80,"cached_input_tokens":8,"output_tokens":12,"total_tokens":92}}}}"#,
            ]
        )

        let affectedDayKeys = try store.refreshChangedProjectedUsageDayKeys(
            codexHome: codexHome.url,
            timezone: .current
        )
        let newEntry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "sessions/new-live.jsonl"
            )
        )

        #expect(affectedDayKeys == ["2026-04-21"])
        #expect(newEntry.lastRequestedAtUnixMs > 0)
    }

    @Test("Given an archived rollout loses its stored content hash, when refreshing projected usage day keys, then metrics classify it as archived hash missing")
    func refreshChangedProjectedUsageDayKeysClassifiesArchivedHashMissingReason() throws {
        let root = try makeTempRoot("codex-session-projection-archived-hash-missing")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/frozen.jsonl",
            sessionID: "session-frozen",
            usageLines: [
                #"{"timestamp":"2026-04-21T12:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":60,"cached_input_tokens":6,"output_tokens":9,"total_tokens":69}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url,
            inventoryCacheTTL: 0
        )
        let recorder = PerformanceRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.performanceNotification,
            object: nil,
            queue: nil
        ) { notification in
            recorder.append(notification.userInfo ?? [:])
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        _ = try store.loadProjectedUsageMinutes(codexHome: codexHome.url)
        let usageIndexDatabaseURL = cacheRoot.url.appendingPathComponent("usage-index-v1.sqlite")
        try sqliteExecute(
            databaseURL: usageIndexDatabaseURL,
            sql: """
            UPDATE usage_entries
            SET content_hash = NULL
            WHERE codex_home_path = ? AND rollout_path = ?;
            """,
            bindings: [
                .text(codexHome.url.path),
                .text("archived_sessions/frozen.jsonl"),
            ]
        )

        let affectedDayKeys = try store.refreshChangedProjectedUsageDayKeys(
            codexHome: codexHome.url,
            timezone: .current
        )
        let refreshedEntry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "archived_sessions/frozen.jsonl"
            )
        )
        let metrics = try #require(
            recorder.payloads.last(where: { payload in
                payload["operation"] as? String == "refresh_projected_usage_day_keys"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )

        #expect(affectedDayKeys == ["2026-04-21"])
        #expect(refreshedEntry.contentHash != nil)
        #expect(metrics["scanned_file_count"] as? Int == 1)
        #expect(metrics["cached_entry_count"] as? Int == 1)
        #expect(metrics["new_rollout_count"] as? Int == 0)
        #expect(metrics["refreshed_live_rollout_count"] as? Int == 0)
        #expect(metrics["refreshed_archived_rollout_count"] as? Int == 1)
        #expect(metrics["live_fingerprint_changed_count"] as? Int == 0)
        #expect(metrics["archived_hash_missing_count"] as? Int == 1)
        #expect(metrics["archived_state_changed_count"] as? Int == 0)
        #expect(metrics["fingerprint_unavailable_count"] as? Int == 0)
        #expect(metrics["skipped_rollout_count"] as? Int == 0)
    }

    @Test("Given an archived rollout entry keeps the wrong archived flag, when refreshing projected usage day keys, then metrics classify it as archived state changed")
    func refreshChangedProjectedUsageDayKeysClassifiesArchivedStateChangedReason() throws {
        let root = try makeTempRoot("codex-session-projection-archived-state-changed")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/mismatched.jsonl",
            sessionID: "session-mismatched",
            usageLines: [
                #"{"timestamp":"2026-04-21T13:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":70,"cached_input_tokens":7,"output_tokens":11,"total_tokens":81}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url,
            inventoryCacheTTL: 0
        )
        let recorder = PerformanceRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.performanceNotification,
            object: nil,
            queue: nil
        ) { notification in
            recorder.append(notification.userInfo ?? [:])
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        _ = try store.loadProjectedUsageMinutes(codexHome: codexHome.url)
        let usageIndexDatabaseURL = cacheRoot.url.appendingPathComponent("usage-index-v1.sqlite")
        try sqliteExecute(
            databaseURL: usageIndexDatabaseURL,
            sql: """
            UPDATE usage_entries
            SET is_archived = 0
            WHERE codex_home_path = ? AND rollout_path = ?;
            """,
            bindings: [
                .text(codexHome.url.path),
                .text("archived_sessions/mismatched.jsonl"),
            ]
        )

        let affectedDayKeys = try store.refreshChangedProjectedUsageDayKeys(
            codexHome: codexHome.url,
            timezone: .current
        )
        let refreshedEntry = try #require(
            try store.loadUsageIndexEntry(
                codexHome: codexHome.url,
                rolloutPath: "archived_sessions/mismatched.jsonl"
            )
        )
        let metrics = try #require(
            recorder.payloads.last(where: { payload in
                payload["operation"] as? String == "refresh_projected_usage_day_keys"
                    && payload["codex_home_path"] as? String == codexHome.url.path
            })
        )

        #expect(affectedDayKeys == ["2026-04-21"])
        #expect(refreshedEntry.isArchived == true)
        #expect(metrics["scanned_file_count"] as? Int == 1)
        #expect(metrics["cached_entry_count"] as? Int == 1)
        #expect(metrics["new_rollout_count"] as? Int == 0)
        #expect(metrics["refreshed_live_rollout_count"] as? Int == 0)
        #expect(metrics["refreshed_archived_rollout_count"] as? Int == 1)
        #expect(metrics["live_fingerprint_changed_count"] as? Int == 0)
        #expect(metrics["archived_hash_missing_count"] as? Int == 0)
        #expect(metrics["archived_state_changed_count"] as? Int == 1)
        #expect(metrics["fingerprint_unavailable_count"] as? Int == 0)
        #expect(metrics["skipped_rollout_count"] as? Int == 0)
    }

    @Test("Given duplicate rollout files split one session across different minutes, when projecting global minute usage, then store merges non-overlapping minutes instead of picking one rollout")
    func loadProjectedUsageMinutesMergesSplitDuplicateSessionMinutes() throws {
        let root = try makeTempRoot("codex-session-minute-merge-split")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/thread-live.jsonl",
            sessionID: "session-merged",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}"#,
            ]
        )
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/thread-copy.jsonl",
            sessionID: "session-merged",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":1,"output_tokens":4,"total_tokens":14}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let expectedMinute0 = try parseISO8601("2026-04-10T10:00:00Z")
        let expectedMinute1 = try parseISO8601("2026-04-10T10:01:00Z")
        let projected = try store.loadProjectedUsageMinutes(
            codexHome: codexHome.url
        )

        #expect(projected.entries.count == 2)
        #expect(projected.entries[0].minuteStartAt == expectedMinute0)
        #expect(projected.entries[0].inputTokens == 100)
        #expect(projected.entries[0].cachedInputTokens == 10)
        #expect(projected.entries[0].outputTokens == 20)
        #expect(projected.entries[1].minuteStartAt == expectedMinute1)
        #expect(projected.entries[1].inputTokens == 10)
        #expect(projected.entries[1].cachedInputTokens == 1)
        #expect(projected.entries[1].outputTokens == 4)
    }

    @Test("Given projected usage spans duplicate rollouts, when loading projected usage summary, then store streams the merged total without materializing minute entries")
    func loadProjectedUsageSummaryAggregatesMergedTotals() throws {
        let root = try makeTempRoot("codex-session-minute-summary")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/thread-live.jsonl",
            sessionID: "session-summary",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}"#,
            ]
        )
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "archived_sessions/thread-copy.jsonl",
            sessionID: "session-summary",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:40Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":90,"cached_input_tokens":9,"output_tokens":18,"total_tokens":108}}}}"#,
                #"{"timestamp":"2026-04-10T10:01:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":22,"total_tokens":122}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        let summary = try store.loadProjectedUsageSummary(codexHome: codexHome.url)
        let requiredSummary = try #require(summary)
        #expect(requiredSummary.totalTokens == 134)
        #expect(requiredSummary.sourceLabel == "global local usage")
    }

    @Test("Given stale minute rows remain in the usage index, when loading logical session usage, then store only aggregates the currently scanned rollout paths")
    func loadLogicalSessionUsageIgnoresStaleIndexedRolloutsOutsideCurrentSnapshot() throws {
        let root = try makeTempRoot("codex-session-logical-usage-stale-index")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()
        _ = try writeUsageRollout(
            codexHome: codexHome,
            rolloutPath: "sessions/current.jsonl",
            sessionID: "thread-live",
            usageLines: [
                #"{"timestamp":"2026-04-10T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":20,"total_tokens":120}}}}"#,
            ]
        )

        let cacheRoot = root.folder("cache-root")
        _ = cacheRoot.createIfNotExists()
        let store = CodexSessionStore(
            defaultProviderID: "openai",
            usageIndexRootDirectory: cacheRoot.url
        )

        _ = try store.loadSessionUsage(
            codexHome: codexHome.url,
            rolloutPath: "sessions/current.jsonl"
        )

        let usageIndexDatabaseURL = cacheRoot.url.appendingPathComponent("usage-index-v1.sqlite")
        try sqliteExecute(
            databaseURL: usageIndexDatabaseURL,
            sql: """
            INSERT INTO session_usage_minutes (
                codex_home_path,
                rollout_path,
                session_id,
                minute_start_unix_ms,
                input_tokens,
                cached_input_tokens,
                output_tokens,
                updated_at_unix_ms
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(codexHome.path),
                .text("archived_sessions/stale.jsonl"),
                .text("thread-live"),
                .int64(1_744_280_000_000),
                .int64(900),
                .int64(90),
                .int64(180),
                .int64(1_744_280_000_000),
            ]
        )

        let logicalUsage = try #require(
            try store.loadLogicalSessionUsage(
                codexHome: codexHome.url,
                threadID: "thread-live",
                rolloutPath: "sessions/current.jsonl"
            )
        )

        #expect(logicalUsage.inputTokens == 100)
        #expect(logicalUsage.cachedInputTokens == 10)
        #expect(logicalUsage.outputTokens == 20)
    }

    @Test("Given selected live and archived sessions, when previewing and rewriting providers, then rollout files and sqlite rows are both updated")
    func rewriteProvidersUpdatesMatchingRolloutsAndSQLiteRows() throws {
        let root = try makeTempRoot("codex-session-store-rewrite")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let liveThreadID = UUID().uuidString.lowercased()
        let archivedThreadID = UUID().uuidString.lowercased()
        let untouchedThreadID = UUID().uuidString.lowercased()

        let liveRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: liveThreadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "provider-one"
        )
        let archivedRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: archivedThreadID,
            timestamp: "2026-04-10T09:00:00Z",
            modelProvider: "provider-one",
            archived: true
        )
        let untouchedRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: untouchedThreadID,
            timestamp: "2026-04-10T08:00:00Z",
            modelProvider: "provider-two"
        )
        try createStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: liveThreadID, title: "Live", modelProvider: "provider-one", updatedAt: 1_000, archived: false),
                (id: archivedThreadID, title: "Archived", modelProvider: "provider-one", updatedAt: 900, archived: true),
                (id: untouchedThreadID, title: "Untouched", modelProvider: "provider-two", updatedAt: 800, archived: false),
            ]
        )

        let store = CodexSessionStore(defaultProviderID: "openai")
        let preview = try store.previewRewrite(
            codexHome: codexHome,
            request: .init(
                threadIDs: [liveThreadID, archivedThreadID],
                targetProviderID: "provider-three"
            )
        )
        let result = try store.rewriteProviders(
            codexHome: codexHome,
            request: .init(
                threadIDs: [liveThreadID, archivedThreadID],
                targetProviderID: "provider-three"
            )
        )

        #expect(preview.sessionCount == 2)
        #expect(preview.liveSessionCount == 1)
        #expect(preview.archivedSessionCount == 1)
        #expect(preview.stateRowCount == 2)
        #expect(result.preview == preview)
        #expect(result.liveRolloutFilesUpdated == 1)
        #expect(result.archivedRolloutFilesUpdated == 1)
        #expect(result.stateRowsUpdated == 2)
        #expect(result.failures.isEmpty)
        #expect(try rolloutSessionMetaProvider(file: liveRollout) == "provider-three")
        #expect(try rolloutSessionMetaProvider(file: archivedRollout) == "provider-three")
        #expect(try rolloutSessionMetaProvider(file: untouchedRollout) == "provider-two")

        let databaseURL = codexHome.file("state_4.sqlite").url
        #expect(
            try sqliteString(
                databaseURL: databaseURL,
                sql: "SELECT model_provider FROM threads WHERE id = ?;",
                bind: liveThreadID
            ) == "provider-three"
        )
        #expect(
            try sqliteString(
                databaseURL: databaseURL,
                sql: "SELECT model_provider FROM threads WHERE id = ?;",
                bind: archivedThreadID
            ) == "provider-three"
        )
        #expect(
            try sqliteString(
                databaseURL: databaseURL,
                sql: "SELECT model_provider FROM threads WHERE id = ?;",
                bind: untouchedThreadID
            ) == "provider-two"
        )
    }

    @Test("Given unrelated malformed rollout file, when rewriting a selected thread, then target rollout and sqlite update still succeed")
    func rewriteProvidersIgnoresMalformedUnrelatedRolloutFiles() throws {
        let root = try makeTempRoot("codex-session-store-rewrite-targeted-rollout")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        let targetRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "provider-one"
        )
        let malformedRollout = codexHome.folder("sessions").folder("2026").folder("04").folder("10").file("broken.jsonl")
        try malformedRollout.overlay(with: "{not-json}\n")

        try createStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: threadID, title: "Live", modelProvider: "provider-one", updatedAt: 1_000, archived: false),
            ]
        )

        let result = try CodexSessionStore(defaultProviderID: "openai").rewriteProviders(
            codexHome: codexHome,
            request: .init(threadIDs: [threadID], targetProviderID: "provider-three")
        )

        #expect(result.liveRolloutFilesUpdated == 1)
        #expect(result.archivedRolloutFilesUpdated == 0)
        #expect(result.stateRowsUpdated == 1)
        #expect(result.failures.isEmpty)
        #expect(try rolloutSessionMetaProvider(file: targetRollout) == "provider-three")
        #expect(try malformedRollout.read() == "{not-json}\n")
        #expect(
            try sqliteString(
                databaseURL: codexHome.file("state_4.sqlite").url,
                sql: "SELECT model_provider FROM threads WHERE id = ?;",
                bind: threadID
            ) == "provider-three"
        )
    }

    @Test("Given many selected live rollout files, when rewriting providers, then all target rollouts still update successfully")
    func rewriteProvidersUpdatesManyTargetedLiveRolloutFiles() throws {
        let root = try makeTempRoot("codex-session-store-rewrite-many-live")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        var targetThreadIDs: [String] = []
        var targetRollouts: [STFile] = []
        var threads: [(id: String, title: String, modelProvider: String, updatedAt: Int64?, archived: Bool)] = []

        for index in 0..<24 {
            let threadID = UUID().uuidString.lowercased()
            targetThreadIDs.append(threadID)
            targetRollouts.append(
                try writeRolloutSessionMeta(
                    codexHome: codexHome,
                    threadID: threadID,
                    timestamp: "2026-04-10T10:00:00Z",
                    modelProvider: "provider-one"
                )
            )
            threads.append(
                (id: threadID, title: "Live \(index)", modelProvider: "provider-one", updatedAt: Int64(1_000 + index), archived: false)
            )
        }

        try createStateDatabase(codexHome: codexHome, threads: threads)

        let result = try CodexSessionStore(defaultProviderID: "openai").rewriteProviders(
            codexHome: codexHome,
            request: .init(threadIDs: targetThreadIDs, targetProviderID: "provider-three")
        )

        #expect(result.liveRolloutFilesUpdated == targetRollouts.count)
        #expect(result.archivedRolloutFilesUpdated == 0)
        #expect(result.stateRowsUpdated == targetThreadIDs.count)
        #expect(result.failures.isEmpty)
        for rollout in targetRollouts {
            #expect(try rolloutSessionMetaProvider(file: rollout) == "provider-three")
        }
    }

    @Test("Given rollout rewrites succeed but sqlite update fails, when rewriting providers, then result includes consistency verification details")
    func rewriteProvidersReportsConsistencyFailuresWhenSQLiteUpdateFails() throws {
        let root = try makeTempRoot("codex-session-store-rewrite-verify")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        let rollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "provider-one"
        )
        try createStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: threadID, title: "Live", modelProvider: "provider-one", updatedAt: 1_000, archived: false),
            ]
        )

        let databaseURL = codexHome.file("state_4.sqlite").url
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: databaseURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: databaseURL.path)
        }

        let store = CodexSessionStore(defaultProviderID: "openai")
        let preview = try store.previewRewrite(
            codexHome: codexHome,
            request: .init(threadIDs: [threadID], targetProviderID: "provider-three")
        )
        let result = try store.rewriteProviders(
            codexHome: codexHome,
            request: .init(threadIDs: [threadID], targetProviderID: "provider-three"),
            confirmedPreview: preview
        )

        #expect(result.preview == preview)
        #expect(result.liveRolloutFilesUpdated == 1)
        #expect(result.stateRowsUpdated == 0)
        #expect(result.failures.contains { $0.contains("state db:") })
        #expect(result.failures.contains { $0.contains("rewrite verification: state db") })
        #expect(try rolloutSessionMetaProvider(file: rollout) == "provider-three")
        #expect(
            try sqliteString(
                databaseURL: databaseURL,
                sql: "SELECT model_provider FROM threads WHERE id = ?;",
                bind: threadID
            ) == "provider-one"
        )
    }

    @Test("Given provider rewrite completes, when store publishes performance metrics, then updated counts and failure count are included")
    func rewriteProvidersPublishesPerformanceMetrics() throws {
        let root = try makeTempRoot("codex-session-store-performance-rewrite")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let threadID = UUID().uuidString.lowercased()
        _ = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: threadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "provider-one"
        )
        try createStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: threadID, title: "Live", modelProvider: "provider-one", updatedAt: 1_000, archived: false),
            ]
        )

        let recorder = PerformanceRecorder()
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.performanceNotification,
            object: nil,
            queue: nil
        ) { notification in
            recorder.append(notification.userInfo ?? [:])
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let result = try CodexSessionStore(defaultProviderID: "openai").rewriteProviders(
            codexHome: codexHome,
            request: .init(threadIDs: [threadID], targetProviderID: "provider-three")
        )

        #expect(result.stateRowsUpdated == 1)
        let metrics = try #require(recorder.payloads.last(where: { ($0["operation"] as? String) == "rewrite_providers" }))
        #expect(metrics["preview_session_count"] as? Int == 1)
        #expect(metrics["state_rows_updated"] as? Int == 1)
        #expect(metrics["live_rollout_files_updated"] as? Int == 1)
        #expect(metrics["failure_count"] as? Int == 0)
        #expect(metrics["codex_home_path"] as? String == codexHome.url.path)
        #expect((metrics["preview_elapsed_ms"] as? Int ?? -1) >= 0)
        #expect((metrics["live_rollout_elapsed_ms"] as? Int ?? -1) >= 0)
        #expect((metrics["archived_rollout_elapsed_ms"] as? Int ?? -1) >= 0)
        #expect((metrics["state_db_elapsed_ms"] as? Int ?? -1) >= 0)
        #expect((metrics["verify_elapsed_ms"] as? Int ?? -1) >= 0)
        #expect((metrics["elapsed_ms"] as? Int ?? -1) >= 0)
        let traceID = try #require(metrics["trace_id"] as? String)
        let completedPhases = recorder.payloads.filter { payload in
            (payload["operation"] as? String) == "rewrite_phase" &&
            (payload["status"] as? String) == "completed" &&
            (payload["trace_id"] as? String) == traceID
        }
        #expect(completedPhases.count == 5)
        #expect(completedPhases.contains { ($0["phase"] as? String) == "preview" })
        #expect(completedPhases.contains { ($0["phase"] as? String) == "live_rollout" })
        #expect(completedPhases.contains { ($0["phase"] as? String) == "archived_rollout" })
        #expect(completedPhases.contains { ($0["phase"] as? String) == "state_db" })
        #expect(completedPhases.contains { ($0["phase"] as? String) == "verify" })
    }

    @Test("Given matching provider groups in rollout files and sqlite, when migrating providers, then all matching sessions move to the new provider")
    func migrateProvidersUpdatesMatchingProviderGroups() throws {
        let root = try makeTempRoot("codex-session-store-migrate")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let liveThreadID = UUID().uuidString.lowercased()
        let archivedThreadID = UUID().uuidString.lowercased()
        let untouchedThreadID = UUID().uuidString.lowercased()

        let liveRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: liveThreadID,
            timestamp: "2026-04-10T10:00:00Z",
            modelProvider: "provider-one"
        )
        let archivedRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: archivedThreadID,
            timestamp: "2026-04-10T09:00:00Z",
            modelProvider: "provider-two",
            archived: true
        )
        let untouchedRollout = try writeRolloutSessionMeta(
            codexHome: codexHome,
            threadID: untouchedThreadID,
            timestamp: "2026-04-10T08:00:00Z",
            modelProvider: "openai"
        )
        try createStateDatabase(
            codexHome: codexHome,
            threads: [
                (id: liveThreadID, title: "Live", modelProvider: "provider-one", updatedAt: 1_000, archived: false),
                (id: archivedThreadID, title: "Archived", modelProvider: "provider-two", updatedAt: 900, archived: true),
                (id: untouchedThreadID, title: "Untouched", modelProvider: "openai", updatedAt: 800, archived: false),
            ]
        )

        let store = CodexSessionStore(defaultProviderID: "openai")
        let report = try store.migrateProviders(
            codexHome: codexHome,
            sourceProviderIDs: ["provider-one", "provider-two"],
            targetProviderID: "provider-three"
        )

        #expect(report.liveRolloutFilesUpdated == 1)
        #expect(report.archivedRolloutFilesUpdated == 1)
        #expect(report.stateRowsUpdated == 2)
        #expect(try rolloutSessionMetaProvider(file: liveRollout) == "provider-three")
        #expect(try rolloutSessionMetaProvider(file: archivedRollout) == "provider-three")
        #expect(try rolloutSessionMetaProvider(file: untouchedRollout) == "openai")

        let databaseURL = codexHome.file("state_4.sqlite").url
        #expect(
            try sqliteString(
                databaseURL: databaseURL,
                sql: "SELECT model_provider FROM threads WHERE id = ?;",
                bind: liveThreadID
            ) == "provider-three"
        )
        #expect(
            try sqliteString(
                databaseURL: databaseURL,
                sql: "SELECT model_provider FROM threads WHERE id = ?;",
                bind: archivedThreadID
            ) == "provider-three"
        )
        #expect(
            try sqliteString(
                databaseURL: databaseURL,
                sql: "SELECT model_provider FROM threads WHERE id = ?;",
                bind: untouchedThreadID
            ) == "openai"
        )
    }
}

private enum SQLiteBinding {
    case text(String)
    case int64(Int64)
    case null
}

private final class WarningRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var messages: [String] = []

    func append(_ message: String) {
        lock.lock()
        messages.append(message)
        lock.unlock()
    }
}

private final class PerformanceRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var payloads: [[AnyHashable: Any]] = []

    func append(_ payload: [AnyHashable: Any]) {
        lock.lock()
        payloads.append(payload)
        lock.unlock()
    }
}
