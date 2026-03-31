import Foundation

public enum ProviderUsageErrorTextFormatter {
    public static func displayText(errorDetail: String, maxLength: Int = 220) -> String {
        let compact = errorDetail
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > maxLength else { return compact }
        let prefixLength = max(0, maxLength - 3)
        return String(compact.prefix(prefixLength)) + "..."
    }

    public static func summaryText(errorDetail: String, isAuthFailure: Bool, maxLength: Int = 140) -> String {
        if isAuthFailure {
            return NSLocalizedString(
                "codex.accounts.error.auth_expired",
                value: "Authentication expired. Please sign in again.",
                comment: "Codex auth expired summary"
            )
        }

        let compact = errorDetail
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > maxLength else { return compact }
        let prefixLength = max(0, maxLength - 3)
        return String(compact.prefix(prefixLength)) + "..."
    }

    public static func detailText(localizedDescription: String, fallbackDescription: String) -> String {
        let trimmed = localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return fallbackDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
