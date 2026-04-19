import Foundation
import STFilePath
import Testing
@testable import CodexProvider

@Suite("CodexSessionScanner")
struct CodexSessionScannerTests {
    @Test("scanFiles discovers live and archived jsonl files with codex-home relative paths")
    func scanFilesDiscoversLiveAndArchivedFiles() throws {
        let root = try makeTempRoot("codex-session-scanner")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        try writeSessionFile(
            codexHome: codexHome,
            directory: "sessions",
            date: "2026/04/10",
            filename: "live.jsonl",
            threadID: "thread-live",
            modelProvider: "OpenAI"
        )
        try writeSessionFile(
            codexHome: codexHome,
            directory: "archived_sessions",
            date: "2026/04/10",
            filename: "archived.jsonl",
            threadID: "thread-archived",
            modelProvider: "Azure"
        )

        let files = CodexSessionScanner.scanFiles(codexHome: codexHome, includeArchived: true)

        #expect(files.count == 2)
        #expect(files.map(\.relativePath) == [
            "archived_sessions/2026/04/10/archived.jsonl",
            "sessions/2026/04/10/live.jsonl",
        ])
        #expect(files.map(\.archived) == [true, false])
    }

    @Test("readSessionMeta trims thread id and normalizes provider id")
    func readSessionMetaNormalizesValues() throws {
        let root = try makeTempRoot("codex-session-scanner-meta")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let file = try writeSessionFile(
            codexHome: codexHome,
            directory: "sessions",
            date: "2026/04/10",
            filename: "meta.jsonl",
            threadID: "  thread-meta  ",
            modelProvider: "  OpenAI  "
        )

        let scannedFile = try #require(
            CodexSessionScanner.scanFiles(codexHome: codexHome, includeArchived: false)
                .first(where: {
                    $0.file.url.standardizedFileURL.path == file.url.standardizedFileURL.path
                })
        )
        let meta = try #require(CodexSessionScanner.readSessionMeta(from: scannedFile))

        #expect(meta.threadID == "thread-meta")
        #expect(meta.modelProvider == "openai")
    }

    @Test("readSessionMeta preserves forked from originator and source")
    func readSessionMetaPreservesRawMetadata() throws {
        let root = try makeTempRoot("codex-session-scanner-raw-meta")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let file = try writeSessionFile(
            codexHome: codexHome,
            directory: "sessions",
            date: "2026/04/10",
            filename: "raw-meta.jsonl",
            threadID: "thread-meta",
            modelProvider: "OpenAI",
            forkedFromID: "parent-thread-01",
            originator: "claude-code",
            source: "cli"
        )

        let scannedFile = try #require(
            CodexSessionScanner.scanFiles(codexHome: codexHome, includeArchived: false)
                .first(where: {
                    $0.file.url.standardizedFileURL.path == file.url.standardizedFileURL.path
                })
        )
        let meta = try #require(CodexSessionScanner.readSessionMeta(from: scannedFile))

        #expect(meta.forkedFromID == "parent-thread-01")
        #expect(meta.originator == "claude-code")
        #expect(meta.source == "cli")
    }

    @Test("scanFiles caches session meta on scanned file entries")
    func scanFilesCachesSessionMeta() throws {
        let root = try makeTempRoot("codex-session-scanner-cache")
        defer { try? root.delete() }

        let codexHome = root.folder("provider")
        _ = codexHome.createIfNotExists()

        let file = try writeSessionFile(
            codexHome: codexHome,
            directory: "sessions",
            date: "2026/04/10",
            filename: "cached-meta.jsonl",
            threadID: "thread-cached",
            modelProvider: "OpenAI"
        )

        let scannedFile = try #require(
            CodexSessionScanner.scanFiles(codexHome: codexHome, includeArchived: false)
                .first(where: {
                    $0.file.url.standardizedFileURL.path == file.url.standardizedFileURL.path
                })
        )

        let cachedMeta = try #require(scannedFile.sessionMeta)
        #expect(cachedMeta.threadID == "thread-cached")
        #expect(cachedMeta.modelProvider == "openai")
    }

    @Test("readSessionMeta returns cached session meta without reopening deleted rollout file")
    func readSessionMetaUsesCachedEntryAfterFileDeletion() throws {
        let root = try makeTempRoot("codex-session-scanner-cache-fallback")
        defer { try? root.delete() }

        let cachedMeta = CodexSessionScanner.SessionMeta(
            threadID: "thread-cached",
            forkedFromID: "parent-thread",
            originator: "codex",
            source: "cli",
            modelProvider: "openai",
            cwd: "/tmp/project",
            timestamp: "2026-04-10T10:00:00Z"
        )
        let missingFile = root.file("missing.jsonl")
        let scannedFile = CodexSessionScanner.ScannedFile(
            file: missingFile,
            relativePath: "sessions/missing.jsonl",
            archived: false,
            fileIdentity: nil,
            sessionMeta: cachedMeta
        )

        let meta = try #require(CodexSessionScanner.readSessionMeta(from: scannedFile))
        #expect(meta.threadID == "thread-cached")
        #expect(meta.forkedFromID == "parent-thread")
        #expect(meta.modelProvider == "openai")
    }

    private func makeTempRoot(_ prefix: String) throws -> STFolder {
        let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        return root
    }

    @discardableResult
    private func writeSessionFile(
        codexHome: STFolder,
        directory: String,
        date: String,
        filename: String,
        threadID: String,
        modelProvider: String,
        forkedFromID: String? = nil,
        originator: String? = nil,
        source: String? = nil
    ) throws -> STFile {
        let parts = date.split(separator: "/").map(String.init)
        var folder = codexHome.folder(directory)
        for part in parts {
            folder = folder.folder(part)
        }
        _ = folder.createIfNotExists()

        let file = folder.file(filename)
        var payload: [String: String] = [
            "id": threadID,
            "timestamp": "2026-04-10T10:00:00Z",
            "cwd": "/tmp/project",
            "model_provider": modelProvider,
        ]
        if let forkedFromID {
            payload["forked_from_id"] = forkedFromID
        }
        if let originator {
            payload["originator"] = originator
        }
        if let source {
            payload["source"] = source
        }
        let sessionMetaData = try JSONSerialization.data(withJSONObject: [
            "timestamp": "2026-04-10T10:00:00Z",
            "type": "session_meta",
            "payload": payload,
        ])
        let sessionMeta = String(decoding: sessionMetaData, as: UTF8.self)
        let userMessage = """
        {"timestamp":"2026-04-10T10:00:01Z","type":"event_msg","payload":{"type":"user_message","message":"hello"}}
        """
        try file.overlay(with: "\(sessionMeta)\n\(userMessage)\n")
        return file
    }
}
