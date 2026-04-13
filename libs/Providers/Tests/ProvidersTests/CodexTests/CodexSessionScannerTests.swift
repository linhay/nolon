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
        modelProvider: String
    ) throws -> STFile {
        let parts = date.split(separator: "/").map(String.init)
        var folder = codexHome.folder(directory)
        for part in parts {
            folder = folder.folder(part)
        }
        _ = folder.createIfNotExists()

        let file = folder.file(filename)
        let sessionMeta = """
        {"timestamp":"2026-04-10T10:00:00Z","type":"session_meta","payload":{"id":"\(threadID)","timestamp":"2026-04-10T10:00:00Z","cwd":"/tmp/project","model_provider":"\(modelProvider)"}}
        """
        let userMessage = """
        {"timestamp":"2026-04-10T10:00:01Z","type":"event_msg","payload":{"type":"user_message","message":"hello"}}
        """
        try file.overlay(with: "\(sessionMeta)\n\(userMessage)\n")
        return file
    }
}
