import XCTest
import ProviderUsage
@testable import nolon

final class AccountDisplayTextSupportTests: XCTestCase {
    func testBDD_GivenBlankPrimaryTitle_WhenResolvingTitle_ThenFallsBackToSecondaryValue() {
        XCTAssertEqual(
            AccountDisplayTextSupport.title(primary: " \n ", fallback: "Fallback"),
            "Fallback"
        )
    }

    func testBDD_GivenWhitespaceSubtitleParts_WhenBuildingSubtitle_ThenOmitsBlankSegments() {
        XCTAssertEqual(
            AccountDisplayTextSupport.subtitle(" gemini@example.com ", " ", "\nalpha"),
            "gemini@example.com • alpha"
        )
    }

    func testBDD_GivenCodexEmailMatchesTitle_WhenBuildingCodexSubtitle_ThenOmitsDuplicateEmail() {
        XCTAssertEqual(
            AccountDisplayTextSupport.codexSubtitle(
                title: "dev@example.com",
                email: " dev@example.com ",
                plan: "pro"
            ),
            "pro"
        )
    }

    func testBDD_GivenAPIKeySummary_WhenResolvingCodexSnapshotLabel_ThenUsesStableKeySuffixName() {
        let account = CodexAuthAccount(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "Legacy",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            relativeAuthPath: "auth/legacy.json"
        )
        let summary = CodexAuthSummary(
            email: nil,
            apiKeySuffix: "abcd",
            cardKind: .officialAPIKey
        )

        XCTAssertEqual(
            AccountDisplayTextSupport.codexSnapshotLabel(summary: summary, account: account),
            "key-abcd"
        )
    }
}
