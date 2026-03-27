import XCTest
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation

final class UsageIssueClassifierTests: XCTestCase {
    func testBDD_GivenGeminiUnsupportedError_WhenClassify_ThenReturnsUnsupported() {
        let provider: UsageProvider = .gemini
        let error = ProviderUsageError.unsupported(.gemini)
        let code = ProviderUsageIssueClassifier.classify(
            providerID: provider.rawValue,
            errorText: error.localizedDescription,
            usageErrorCode: usageErrorCode(from: error)
        )
        XCTAssertEqual(code, .unsupported)
    }

    func testBDD_GivenTokenError_WhenClassify_ThenReturnsAuth() {
        let provider: UsageProvider = .copilot
        let error = ProviderUsageError.missingToken(.copilot)
        let code = ProviderUsageIssueClassifier.classify(
            providerID: provider.rawValue,
            errorText: error.localizedDescription,
            usageErrorCode: usageErrorCode(from: error)
        )
        XCTAssertEqual(code, .auth)
    }

    func testBDD_GivenGeminiProvider_WhenBuildingHints_ThenContainsOAuthHint() {
        let hints = ProviderUsageIssueClassifier.hints(providerID: UsageProvider.gemini.rawValue, code: .unsupported)
        XCTAssertTrue(
            hints.contains(where: { $0.contains("Gemini OAuth") }),
            "Expected gemini hints to include OAuth login guidance."
        )
    }

    private func usageErrorCode(from error: Error) -> String? {
        guard let usageError = error as? ProviderUsageError else { return nil }
        switch usageError {
        case .unsupported:
            return "unsupported"
        case .missingToken:
            return "missingToken"
        case .missingAccount:
            return "missingAccount"
        case .authExpired:
            return "authExpired"
        }
    }
}
