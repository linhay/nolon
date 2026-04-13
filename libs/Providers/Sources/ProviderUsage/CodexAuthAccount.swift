import Foundation
import STJSON
import CryptoKit

public struct CodexAuthAccount: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    /// Relative path under `~/.nolon/codex/` (e.g. `auth/work.json`).
    public var relativeAuthPath: String

    public nonisolated init(id: UUID = UUID(), name: String, createdAt: Date = Date(), relativeAuthPath: String) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.relativeAuthPath = relativeAuthPath
    }

    public nonisolated static func hashHex(for authJSONString: String) -> String {
        let data = Data(authJSONString.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public struct CodexAuthSummary: Hashable, Sendable {
    public enum CardKind: String, Codable, Hashable, Sendable {
        case chatgptAccount
        case officialAPIKey
        case relayProfile

        public var isSelfManagedConfiguredAccount: Bool {
            switch self {
            case .officialAPIKey, .relayProfile:
                return true
            case .chatgptAccount:
                return false
            }
        }
    }

    public var email: String?
    public var accountID: String?
    public var apiKeySuffix: String?
    public var plan: String?
    /// Deprecated compatibility field from `nolon.account.name`.
    /// New auth files no longer persist this field; display labels are derived.
    public var name: String?
    public var cardKind: CardKind?
    public var relayBaseURL: String?
    public var relayModelProvider: String?
    public var lastLoginAt: Date?
    public var lastSyncSucceededAt: Date?
    public var lastSyncFailedAt: Date?
    public var lastSyncFailureMessage: String?

    public nonisolated init(
        email: String? = nil,
        accountID: String? = nil,
        apiKeySuffix: String? = nil,
        plan: String? = nil,
        name: String? = nil,
        cardKind: CardKind? = nil,
        relayBaseURL: String? = nil,
        relayModelProvider: String? = nil,
        lastLoginAt: Date? = nil,
        lastSyncSucceededAt: Date? = nil,
        lastSyncFailedAt: Date? = nil,
        lastSyncFailureMessage: String? = nil
    ) {
        self.email = email
        self.accountID = accountID
        self.apiKeySuffix = apiKeySuffix
        self.plan = plan
        self.name = name
        self.cardKind = cardKind
        self.relayBaseURL = relayBaseURL
        self.relayModelProvider = relayModelProvider
        self.lastLoginAt = lastLoginAt
        self.lastSyncSucceededAt = lastSyncSucceededAt
        self.lastSyncFailedAt = lastSyncFailedAt
        self.lastSyncFailureMessage = lastSyncFailureMessage
    }

    public nonisolated static func fromJSONString(_ string: String) -> CodexAuthSummary {
        guard let data = string.data(using: .utf8),
              let json = try? JSON(data: data)
        else {
            return CodexAuthSummary()
        }

        var email = (json["email"].string
            ?? json["user"]["email"].string
            ?? json["nolon"]["account"]["email"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if email?.isEmpty == true { email = nil }
        let name = json["nolon"]["account"]["name"].string?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let apiKey = json["OPENAI_API_KEY"].string?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var plan = (json["plan"].string
            ?? json["subscription"]["plan"].string
            ?? json["account"]["plan"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if plan?.isEmpty == true { plan = nil }

        let idToken = (json["tokens"]["id_token"].string
            ?? json["tokens"]["idToken"].string
            ?? json["id_token"].string
            ?? json["idToken"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        let idTokenPayload = idToken.flatMap(decodeJWTPayloadJSON)
        let accountID = canonicalAccountID(json: json, payload: idTokenPayload)

        if plan == nil,
           let payload = idTokenPayload
        {
            let derived = (payload["https://api.openai.com/auth"]["chatgpt_plan_type"].string
                ?? payload["auth"]["chatgpt_plan_type"].string
                ?? payload["plan"].string
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let derived, !derived.isEmpty {
                plan = derived
            }
        }

        let suffix: String?
        if let apiKey, apiKey.count >= 4 {
            suffix = String(apiKey.suffix(4))
        } else {
            suffix = nil
        }

        let relayBaseURL = json["nolon"]["relay"]["base_url"].string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let relayModelProvider = json["nolon"]["relay"]["model_provider"].string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cardKind = resolveCardKind(
            explicitKind: json["nolon"]["account"]["kind"].string,
            authMode: json["auth_mode"].string,
            hasRelayBlock: json["nolon"]["relay"] != JSON.null && json["nolon"]["relay"].dictionaryObject?.isEmpty == false
        )

        let (lastLoginAt, lastSyncSucceededAt, lastSyncFailedAt, lastSyncFailureMessage) = readSyncMetadata(json: json)

        return CodexAuthSummary(
            email: email,
            accountID: accountID,
            apiKeySuffix: suffix,
            plan: plan,
            name: name?.isEmpty == true ? nil : name,
            cardKind: cardKind,
            relayBaseURL: relayBaseURL?.isEmpty == true ? nil : relayBaseURL,
            relayModelProvider: relayModelProvider?.isEmpty == true ? nil : relayModelProvider,
            lastLoginAt: lastLoginAt,
            lastSyncSucceededAt: lastSyncSucceededAt,
            lastSyncFailedAt: lastSyncFailedAt,
            lastSyncFailureMessage: lastSyncFailureMessage
        )
    }

    public nonisolated static func fromJSONData(_ data: Data) -> CodexAuthSummary {
        guard let json = try? JSON(data: data) else { return CodexAuthSummary() }

        var email = (json["email"].string
            ?? json["user"]["email"].string
            ?? json["nolon"]["account"]["email"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if email?.isEmpty == true { email = nil }
        let name = json["nolon"]["account"]["name"].string?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let apiKey = json["OPENAI_API_KEY"].string?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var plan = (json["plan"].string
            ?? json["subscription"]["plan"].string
            ?? json["account"]["plan"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if plan?.isEmpty == true { plan = nil }

        let idToken = (json["tokens"]["id_token"].string
            ?? json["tokens"]["idToken"].string
            ?? json["id_token"].string
            ?? json["idToken"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        let idTokenPayload = idToken.flatMap(decodeJWTPayloadJSON)
        let accountID = canonicalAccountID(json: json, payload: idTokenPayload)

        if plan == nil,
           let payload = idTokenPayload
        {
            let derived = (payload["https://api.openai.com/auth"]["chatgpt_plan_type"].string
                ?? payload["auth"]["chatgpt_plan_type"].string
                ?? payload["plan"].string
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let derived, !derived.isEmpty {
                plan = derived
            }
        }

        let suffix: String?
        if let apiKey, apiKey.count >= 4 {
            suffix = String(apiKey.suffix(4))
        } else {
            suffix = nil
        }

        let relayBaseURL = json["nolon"]["relay"]["base_url"].string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let relayModelProvider = json["nolon"]["relay"]["model_provider"].string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cardKind = resolveCardKind(
            explicitKind: json["nolon"]["account"]["kind"].string,
            authMode: json["auth_mode"].string,
            hasRelayBlock: json["nolon"]["relay"] != JSON.null && json["nolon"]["relay"].dictionaryObject?.isEmpty == false
        )

        let (lastLoginAt, lastSyncSucceededAt, lastSyncFailedAt, lastSyncFailureMessage) = readSyncMetadata(json: json)

        return CodexAuthSummary(
            email: email,
            accountID: accountID,
            apiKeySuffix: suffix,
            plan: plan,
            name: name?.isEmpty == true ? nil : name,
            cardKind: cardKind,
            relayBaseURL: relayBaseURL?.isEmpty == true ? nil : relayBaseURL,
            relayModelProvider: relayModelProvider?.isEmpty == true ? nil : relayModelProvider,
            lastLoginAt: lastLoginAt,
            lastSyncSucceededAt: lastSyncSucceededAt,
            lastSyncFailedAt: lastSyncFailedAt,
            lastSyncFailureMessage: lastSyncFailureMessage
        )
    }

    public nonisolated func preferredDisplayName(fallbackFileStem: String? = nil) -> String {
        let normalizedFallback = fallbackFileStem?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let normalizedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let normalizedEmail {
            return normalizedEmail
        }

        switch cardKind {
        case .chatgptAccount:
            if let accountID = accountID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                return accountID
            }
        case .officialAPIKey:
            if let apiKeySuffix = apiKeySuffix?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                return "key-\(apiKeySuffix)"
            }
        case .relayProfile:
            if let modelProvider = relayModelProvider?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                return modelProvider
            }
            if let relayBaseURL = relayBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
               let host = URL(string: relayBaseURL)?.host?.trimmingCharacters(in: .whitespacesAndNewlines),
               !host.isEmpty
            {
                return host
            }
            if let apiKeySuffix = apiKeySuffix?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                return "key-\(apiKeySuffix)"
            }
        case .none:
            if let apiKeySuffix = apiKeySuffix?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                return "key-\(apiKeySuffix)"
            }
        }

        if let legacyName = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            return legacyName
        }
        if let normalizedFallback {
            return normalizedFallback
        }
        return "account"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension CodexAuthSummary {
    nonisolated static func resolveCardKind(
        explicitKind: String?,
        authMode: String?,
        hasRelayBlock: Bool
    ) -> CardKind? {
        if let explicitKind,
           let kind = CardKind(rawValue: explicitKind.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            return kind
        }

        switch authMode?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "apikey":
            return hasRelayBlock ? .relayProfile : .officialAPIKey
        case "chatgpt", "chatgptAuthTokens":
            return .chatgptAccount
        default:
            return hasRelayBlock ? .relayProfile : nil
        }
    }

    nonisolated static func parseISODate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    nonisolated static func readSyncMetadata(json: JSON) -> (Date?, Date?, Date?, String?) {
        let account = json["nolon"]["account"]
        let login = account["lastLoginAt"].string.flatMap(parseISODate)
        let success = account["lastSyncSucceededAt"].string.flatMap(parseISODate)
        let failed = account["lastSyncFailedAt"].string.flatMap(parseISODate)
        let failureMessage = account["lastSyncFailureMessage"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (login, success, failed, failureMessage?.isEmpty == true ? nil : failureMessage)
    }

    nonisolated static func canonicalAccountID(json: JSON, payload: JSON?) -> String? {
        let candidates: [String?] = [
            payload?["https://api.openai.com/auth"]["chatgpt_account_id"].string,
            payload?["auth"]["chatgpt_account_id"].string,
            json["tokens"]["account_id"].string,
            json["tokens"]["accountId"].string,
            json["chatgpt_account_id"].string,
            json["chatgptAccountId"].string,
            json["account_id"].string,
            json["accountId"].string
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    nonisolated static func decodeJWTPayloadJSON(_ jwt: String) -> JSON? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        guard let payloadData = base64URLDecode(String(parts[1])) else { return nil }
        return try? JSON(data: payloadData)
    }

    nonisolated static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }
}
