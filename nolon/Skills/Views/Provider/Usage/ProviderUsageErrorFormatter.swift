import Foundation
import ProviderUsage

enum ProviderUsageErrorFormatter {
    static func isAuthFailure(error: Error) -> Bool {
        CodexAuthFailureClassifier.isAuthFailure(errorText: detailText(error: error))
    }

    static func summaryText(error: Error, maxLength: Int = 140) -> String {
        if isAuthFailure(error: error) {
            return NSLocalizedString(
                "codex.accounts.error.auth_expired",
                value: "Authentication expired. Please sign in again.",
                comment: "Codex auth expired summary"
            )
        }

        let compact = detailText(error: error)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > maxLength else { return compact }
        let prefixLength = max(0, maxLength - 3)
        return String(compact.prefix(prefixLength)) + "..."
    }

    static func detailText(error: Error) -> String {
        let trimmed = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return String(describing: error).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

