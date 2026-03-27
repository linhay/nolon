import Testing
import Foundation
import ProviderUsage
import NolonUIFoundation
@testable import nolon

private enum ProviderUsageErrorFormatterTestError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(text):
            return text
        }
    }
}

struct ProviderUsageErrorFormatterTests {
    @Test("BDD: Given auth expired error when formatting summary then returns localized auth expired text")
    func testBDD_GivenAuthExpiredError_WhenFormattingSummary_ThenReturnsLocalizedAuthExpiredText() {
        let error = ProviderUsageErrorFormatterTestError.message("Unauthorized: session expired")
        let detail = ProviderUsageErrorTextFormatter.detailText(
            localizedDescription: error.localizedDescription,
            fallbackDescription: String(describing: error)
        )
        let summary = ProviderUsageErrorTextFormatter.summaryText(
            errorDetail: detail,
            isAuthFailure: CodexAuthFailureClassifier.isAuthFailure(errorText: detail),
            maxLength: 140
        )
        #expect(
            summary.contains("Authentication expired")
                || summary.contains("认证已失效")
        )
    }
}
