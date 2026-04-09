import Foundation
import ProviderUsage
import NolonUIFoundation

enum ProviderUsageErrorPresentationSupport {
    static func detailText(error: Error) -> String {
        ProviderUsageErrorTextFormatter.detailText(
            localizedDescription: error.localizedDescription,
            fallbackDescription: String(describing: error)
        )
    }

    static func displayText(error: Error) -> String {
        ProviderUsageErrorTextFormatter.displayText(errorDetail: detailText(error: error))
    }

    static func summaryText(error: Error, maxLength: Int = 140) -> String {
        let detail = detailText(error: error)
        return ProviderUsageErrorTextFormatter.summaryText(
            errorDetail: detail,
            isAuthFailure: CodexAuthFailureClassifier.isAuthFailure(errorText: detail),
            maxLength: maxLength
        )
    }

    static func authExpiredSummaryText() -> String {
        NSLocalizedString(
            "codex.accounts.error.auth_expired",
            value: "Authentication expired. Please sign in again.",
            comment: "Codex auth expired summary"
        )
    }
}

struct CodexAccountFailurePresentation: Equatable {
    let hasFailure: Bool
    let hasPersistedFailure: Bool
    let isAuthFailure: Bool
    let rawDetail: String?
    let detail: String?
    let summary: String?
}

enum CodexAccountFailurePresentationBuilder {
    static func build(
        liveFailureError: Error?,
        persistedFailureMessage: String?,
        canRelogin: Bool
    ) -> CodexAccountFailurePresentation {
        let persistedDetail = TextNormalizationSupport.trimmed(persistedFailureMessage)
        let rawDetail = persistedDetail ?? liveFailureError.map { ProviderUsageErrorPresentationSupport.detailText(error: $0) }
        let detail = rawDetail.map { ProviderUsageErrorTextFormatter.displayText(errorDetail: $0) }
        let isAuthFailure = rawDetail.map { CodexAuthFailureClassifier.isAuthFailure(errorText: $0) } ?? false

        let summary: String? = {
            if let liveFailureError {
                return ProviderUsageErrorPresentationSupport.summaryText(error: liveFailureError)
            }
            if canRelogin, isAuthFailure {
                return ProviderUsageErrorPresentationSupport.authExpiredSummaryText()
            }
            return detail
        }()

        return CodexAccountFailurePresentation(
            hasFailure: liveFailureError != nil || rawDetail != nil,
            hasPersistedFailure: persistedDetail != nil,
            isAuthFailure: isAuthFailure,
            rawDetail: rawDetail,
            detail: detail,
            summary: summary
        )
    }
}
