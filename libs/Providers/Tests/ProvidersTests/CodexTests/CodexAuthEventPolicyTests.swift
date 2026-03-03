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
            isAuthFolderChange: false,
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
            isAuthFolderChange: false,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        #expect(ignored == false)
    }

    @Test("Given known account file renamed inside auth folder, when evaluating policy, then rename is not ignored")
    func knownRenameInsideAuthFolderIsNotIgnored() {
        let changedPath = "/Users/test/.nolon/codex/auth/personal-account.json"
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

    @Test("Given delete suppression mark, when event kind differs, then change is not suppressed")
    func suppressionKindMismatchIsNotSuppressed() {
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.markOperation(
            filePath: "/tmp/auth/work.json",
            folderPath: "/tmp/auth",
            kind: .deleted,
            ttl: 10,
            now: now
        )

        let suppressed = store.consumeSuppression(
            path: "/tmp/auth/work.json",
            kind: .modified,
            now: now.addingTimeInterval(0.2)
        )
        #expect(suppressed == false)
    }

    @Test("Given delete suppression mark, when matching delete event arrives twice, then only first event is suppressed")
    func suppressionConsumedAfterFirstMatch() {
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.markOperation(
            filePath: "/tmp/auth/work.json",
            folderPath: "/tmp/auth",
            kind: .deleted,
            ttl: 10,
            now: now
        )

        let firstSuppressed = store.consumeSuppression(
            path: "/tmp/auth/work.json",
            kind: .deleted,
            now: now.addingTimeInterval(0.2)
        )
        let secondSuppressed = store.consumeSuppression(
            path: "/tmp/auth/work.json",
            kind: .deleted,
            now: now.addingTimeInterval(0.3)
        )
        #expect(firstSuppressed == true)
        #expect(secondSuppressed == false)
    }

    @Test("Given delete suppression mark on auth folder, when child delete event arrives, then child event is suppressed")
    func childDeleteEventUnderMarkedFolderIsSuppressed() {
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.markOperation(
            filePath: "/tmp/auth/work.json",
            folderPath: "/tmp/auth",
            kind: .deleted,
            ttl: 10,
            now: now
        )

        let suppressed = store.consumeSuppression(
            path: "/tmp/auth/new.json",
            kind: .deleted,
            now: now.addingTimeInterval(0.2)
        )
        #expect(suppressed == true)
    }
}
