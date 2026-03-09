import Foundation

public enum CodexAuthFailureClassifier {
    private static let authFailureKeywords: [String] = [
        "401",
        "unauthorized",
        "auth",
        "token",
        "login",
        "refresh_token_invalidated",
        "refresh_token_revoked",
        "refresh_token_expired",
    ]

    public static func isAuthFailure(errorText: String) -> Bool {
        let normalized = errorText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return authFailureKeywords.contains { normalized.contains($0) }
    }

    public static func shouldSkipRefresh(summary: CodexAuthSummary) -> Bool {
        if summary.cardKind == .chatgptAccount {
            return false
        }
        if summary.lastSyncFailedAt != nil {
            return true
        }
        guard let message = summary.lastSyncFailureMessage else { return false }
        return !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
