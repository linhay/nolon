import Foundation

public enum ProviderUsageAccountDisplayNameResolver {
    public static func resolve(
        email: String?,
        summaryAccountID: String?,
        cardKind: String?,
        apiKeySuffix: String?,
        relayModelProvider: String?,
        relayBaseURL: String?,
        relativeAuthPath: String?,
        defaultName: String,
        accountID: UUID?
    ) -> String {
        let normalizedEmail = normalizedNonEmpty(email)
        if let normalizedEmail {
            return normalizedEmail
        }

        switch cardKind {
        case "chatgptAccount":
            if let summaryAccountID = normalizedNonEmpty(summaryAccountID) {
                return summaryAccountID
            }
        case "officialAPIKey":
            if let suffix = normalizedKeySuffix(apiKeySuffix) {
                return "key-\(suffix)"
            }
        case "relayProfile":
            if let provider = normalizedNonEmpty(relayModelProvider) {
                return provider
            }
            if let host = relayHost(relayBaseURL) {
                return host
            }
            if let suffix = normalizedKeySuffix(apiKeySuffix) {
                return "key-\(suffix)"
            }
        default:
            if let suffix = normalizedKeySuffix(apiKeySuffix) {
                return "key-\(suffix)"
            }
        }

        if let fallbackStem = fallbackFileStem(relativeAuthPath) {
            return fallbackStem
        }

        let normalizedDefaultName = defaultName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedDefaultName.isEmpty {
            return normalizedDefaultName
        }

        if let accountID {
            return accountID.uuidString
        }
        return "account"
    }

    private static func fallbackFileStem(_ relativeAuthPath: String?) -> String? {
        guard let relativeAuthPath else { return nil }
        let trimmed = relativeAuthPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stem = URL(fileURLWithPath: trimmed).deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stem.isEmpty ? nil : stem
    }

    private static func relayHost(_ baseURL: String?) -> String? {
        guard let baseURL = normalizedNonEmpty(baseURL),
              let host = URL(string: baseURL)?.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty
        else {
            return nil
        }
        return host
    }

    private static func normalizedKeySuffix(_ suffix: String?) -> String? {
        normalizedNonEmpty(suffix)
    }

    private static func normalizedNonEmpty(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
