import Foundation
import Testing
@testable import ProviderUsage

@Suite("GeminiSessionUsageSupport")
struct GeminiSessionUsageSupportTests {
    @Test("Resolves global Gemini tmp directory as session root")
    func defaultSessionRoot_resolvesTmpDirectory() {
        let root = GeminiSessionUsageSupport.defaultSessionRoot(
            environment: ["HOME": "/Users/tester"]
        )

        #expect(root?.path == "/Users/tester/.gemini/tmp")
    }

    @Test("Lists only session json files under chats directories inside tmp root")
    func defaultListSessionFiles_limitsToChatsSessionJSON() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-gemini-session-root-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let matchingA = root.appendingPathComponent("project-a/chats/session-1.json")
        let matchingB = root.appendingPathComponent("project-b/nested/chats/session-2.json")
        let ignoredNonJSON = root.appendingPathComponent("project-a/chats/session-3.txt")
        let ignoredOutsideChats = root.appendingPathComponent("project-a/logs/session-4.json")
        let ignoredPrefix = root.appendingPathComponent("project-a/chats/transcript-1.json")

        for url in [matchingA, matchingB, ignoredNonJSON, ignoredOutsideChats, ignoredPrefix] {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "{}".write(to: url, atomically: true, encoding: .utf8)
        }

        let files = try GeminiSessionUsageSupport.defaultListSessionFiles(root: root)

        #expect(files.map(\.path) == [matchingA.path, matchingB.path].sorted())
    }
}
