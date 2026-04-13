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
        archived: Bool = false
    ) throws -> STFile {
        let rootFolder = archived ? codexHome.folder("archived_sessions") : codexHome.folder("sessions")
        let dayFolder = rootFolder.folder("2026").folder("04").folder("10")
        _ = dayFolder.createIfNotExists()

        let file = dayFolder.file("rollout-2026-04-10T10-00-00-\(threadID).jsonl")
        var payload: [String: Any] = [
            "id": threadID,
            "timestamp": timestamp,
            "cwd": "/tmp/project",
            "source": "cli",
        ]
        if let modelProvider {
            payload["model_provider"] = modelProvider
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
        let observer = NotificationCenter.default.addObserver(
            forName: CodexSessionStore.warningNotification,
            object: nil,
            queue: nil
        ) { notification in
            if let message = notification.userInfo?["message"] as? String {
                warningRecorder.append(message)
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let snapshot = try CodexSessionStore(defaultProviderID: "openai").loadSnapshot(codexHome: codexHome)

        #expect(snapshot.availableProviderIDs == ["openai"])
        #expect(warningRecorder.messages.count == 1)
        #expect(warningRecorder.messages.first?.contains("config.toml") == true)
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
        let metrics = try #require(recorder.payloads.last)
        #expect(metrics["operation"] as? String == "load_snapshot")
        #expect(metrics["session_count"] as? Int == 1)
        #expect(metrics["scanned_file_count"] as? Int == 1)
        #expect((metrics["elapsed_ms"] as? Int ?? -1) >= 0)
        #expect((metrics["trace_id"] as? String)?.isEmpty == false)
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
