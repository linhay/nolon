import XCTest
import CodexProvider
@testable import nolon

final class CodexBinaryDownsinkMigrationTests: XCTestCase {
    func testBDD_GivenAppBinaryManagerType_WhenCheckingMigrationBoundary_ThenUsesCodexProviderType() {
        XCTAssertEqual(
            ObjectIdentifier(CodexBinaryManager.self),
            ObjectIdentifier(CodexProvider.CodexBinaryManager.self)
        )
    }

    func testBDD_GivenAppBinaryManifestType_WhenCheckingMigrationBoundary_ThenUsesCodexProviderType() {
        XCTAssertEqual(
            ObjectIdentifier(CodexBinaryManifest.self),
            ObjectIdentifier(CodexProvider.CodexBinaryManifest.self)
        )
        XCTAssertEqual(
            ObjectIdentifier(ManagedCodexVersion.self),
            ObjectIdentifier(CodexProvider.ManagedCodexVersion.self)
        )
    }
}
