import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
import NolonResourceKit
@testable import nolon

final class CodexAuthEventPolicyTests: XCTestCase {
    func testBDD_GivenKnownAccountFileRenamedToTrash_WhenEvaluatingPolicy_ThenRenameIsIgnored() {
        // Given
        let changedPath = "/Users/test/.Trash/personal-account.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: false,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertTrue(ignored)
    }

    func testBDD_GivenUnknownRenamedFile_WhenEvaluatingPolicy_ThenRenameIsNotIgnored() {
        // Given
        let changedPath = "/Users/test/.Trash/unknown.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: false,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertFalse(ignored)
    }

    func testBDD_GivenActiveAuthFileRenamed_WhenEvaluatingPolicy_ThenRenameIsNotIgnored() {
        // Given
        let changedPath = "/Users/test/.codex/auth.json"
        let knownFiles: Set<String> = ["auth.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: true,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertFalse(ignored)
    }

    func testBDD_GivenKnownAccountRenameInsideAuthFolder_WhenEvaluatingPolicy_ThenRenameIsNotIgnored() {
        // Given
        let changedPath = "/Users/test/.nolon/codex/auth/personal-account.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertFalse(ignored)
    }
}
