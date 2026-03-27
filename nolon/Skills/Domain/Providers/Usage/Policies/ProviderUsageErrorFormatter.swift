import Foundation
import ProviderUsage
import NolonUIFoundation

enum ProviderUsageErrorFormatter {
    static func isAuthFailure(error: Error) -> Bool {
        CodexAuthFailureClassifier.isAuthFailure(errorText: detailText(error: error))
    }

    static func summaryText(error: Error, maxLength: Int = 140) -> String {
        let detail = detailText(error: error)
        return ProviderUsageErrorTextFormatter.summaryText(
            errorDetail: detail,
            isAuthFailure: CodexAuthFailureClassifier.isAuthFailure(errorText: detail),
            maxLength: maxLength
        )
    }

    static func detailText(error: Error) -> String {
        ProviderUsageErrorTextFormatter.detailText(
            localizedDescription: error.localizedDescription,
            fallbackDescription: String(describing: error)
        )
    }
}
