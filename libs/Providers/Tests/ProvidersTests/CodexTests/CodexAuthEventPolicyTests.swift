import Foundation
import Testing
@testable import ProviderUsage

@Suite("CodexAuthEventPolicy")
struct CodexAuthEventPolicyTests {
    @Test("Given known account file renamed to trash, when evaluating policy, then rename is ignored")
    func knownAuthFileRenameIsIgnored() {
        let changedPath = "/Users/test/.Trash/personal-account.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        #expect(ignored)
    }

    @Test("Given unknown renamed file, when evaluating policy, then rename is not ignored")
    func unknownRenamedFileIsNotIgnored() {
        let changedPath = "/Users/test/.Trash/unknown.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        #expect(ignored == false)
    }

    @Test("Given active auth file renamed, when evaluating policy, then rename is not ignored")
    func activeAuthFileRenameIsNotIgnored() {
        let changedPath = "/Users/test/.codex/auth.json"
        let knownFiles: Set<String> = ["auth.json"]

        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: true,
            knownAuthFileNames: knownFiles
        )

        #expect(ignored == false)
    }
}

@Suite("CodexAuthChangeSuppressionStore")
struct CodexAuthChangeSuppressionStoreTests {
    @Test("Given marked file path, when checking within window, then suppression is true")
    func markedFilePathSuppressed() {
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/work.json", folderPath: "/tmp/auth", ttl: 1.0, now: now)

        let suppressed = store.shouldSuppress(path: "/tmp/auth/work.json", now: now.addingTimeInterval(0.2))
        #expect(suppressed)
    }

    @Test("Given marked folder path, when child file changes, then suppression is true")
    func childPathUnderFolderSuppressed() {
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/work.json", folderPath: "/tmp/auth", ttl: 1.0, now: now)

        let suppressed = store.shouldSuppress(path: "/tmp/auth/another.json", now: now.addingTimeInterval(0.3))
        #expect(suppressed)
    }

    @Test("Given suppression expired, when checking path, then suppression is false")
    func suppressionExpires() {
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/work.json", folderPath: "/tmp/auth", ttl: 0.5, now: now)

        let suppressed = store.shouldSuppress(path: "/tmp/auth/work.json", now: now.addingTimeInterval(0.6))
        #expect(suppressed == false)
    }

    @Test("Given no marks, when checking path, then suppression is false")
    func noMarksNotSuppressed() {
        var store = CodexAuthChangeSuppressionStore()
        let suppressed = store.shouldSuppress(path: "/tmp/auth/work.json", now: Date())
        #expect(suppressed == false)
    }
}
