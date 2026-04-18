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
        usageLines: [String]
    ) throws -> STFile {
        let file = codexHome.file(rolloutPath)
        _ = file.parentFolder()?.createIfNotExists()

        let content = ([
            #"{"timestamp":"2026-04-10T10:00:00Z","type":"session_meta","payload":{"id":"\#(sessionID)"}}"#,
            #"{"timestamp":"2026-04-10T10:00:01Z","type":"turn_context","payload":{"model":"\#(model)"}}"#,
        ] + usageLines).joined(separator: "\n") + "\n"

        try file.overlay(with: content)
        return file
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
        let metrics = try #require(recorder.payloads.last)
        #expect(metrics["operation"] as? String == "load_snapshot")
        #expect(metrics["session_count"] as? Int == 1)
        #expect(metrics["scanned_file_count"] as? Int == 1)
        #expect(metrics["codex_home_path"] as? String == codexHome.url.path)
        #expect((metrics["elapsed_ms"] as? Int ?? -1) >= 0)
        #expect((metrics["trace_id"] as? String)?.isEmpty == false)
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
