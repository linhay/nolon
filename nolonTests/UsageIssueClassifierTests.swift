import XCTest
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

final class UsageIssueClassifierTests: XCTestCase {
    func testBDD_GivenGeminiUnsupportedError_WhenClassify_ThenReturnsUnsupported() {
        let code = UsageIssueClassifier.classify(
            provider: .gemini,
            error: ProviderUsageError.unsupported(.gemini)
        )
        XCTAssertEqual(code, .unsupported)
    }

    func testBDD_GivenTokenError_WhenClassify_ThenReturnsAuth() {
        let code = UsageIssueClassifier.classify(
            provider: .copilot,
            error: ProviderUsageError.missingToken(.copilot)
        )
        XCTAssertEqual(code, .auth)
    }

    func testBDD_GivenGeminiProvider_WhenBuildingHints_ThenContainsOAuthHint() {
        let hints = UsageIssueClassifier.hints(provider: .gemini, code: .unsupported)
        XCTAssertTrue(
            hints.contains(where: { $0.contains("Gemini OAuth") }),
            "Expected gemini hints to include OAuth login guidance."
        )
    }
}
