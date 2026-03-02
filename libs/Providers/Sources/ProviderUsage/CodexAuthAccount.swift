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
    public var email: String?
    public var accountID: String?
    public var apiKeySuffix: String?
    public var plan: String?
    public var lastLoginAt: Date?
    public var lastSyncSucceededAt: Date?
    public var lastSyncFailedAt: Date?
    public var lastSyncFailureMessage: String?

    public nonisolated init(
        email: String? = nil,
        accountID: String? = nil,
        apiKeySuffix: String? = nil,
        plan: String? = nil,
        lastLoginAt: Date? = nil,
        lastSyncSucceededAt: Date? = nil,
        lastSyncFailedAt: Date? = nil,
        lastSyncFailureMessage: String? = nil
    ) {
        self.email = email
        self.accountID = accountID
        self.apiKeySuffix = apiKeySuffix
        self.plan = plan
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
            ?? json["profile"]["email"].string
            ?? json["nolon"]["account"]["email"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if email?.isEmpty == true { email = nil }

        if email == nil,
           let idToken = (json["tokens"]["id_token"].string
               ?? json["tokens"]["idToken"].string
               ?? json["id_token"].string
               ?? json["idToken"].string
           )?.trimmingCharacters(in: .whitespacesAndNewlines),
           let payload = decodeJWTPayloadJSON(idToken),
           let derived = (payload["email"].string
               ?? payload["https://api.openai.com/profile"]["email"].string
               ?? payload["profile"]["email"].string
           )?.trimmingCharacters(in: .whitespacesAndNewlines),
           !derived.isEmpty
        {
            email = derived
        }

        let apiKey = (json["OPENAI_API_KEY"].string
            ?? json["openai_api_key"].string
            ?? json["api_key"].string
            ?? json["apiKey"].string
            ?? json["token"].string
            ?? json["access_token"].string
            ?? json["tokens"]["access_token"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountIDCandidates: [String?] = [
            json["account"]["id"].string,
            json["tokens"]["account_id"].string,
            json["tokens"]["accountId"].string,
            json["chatgpt_account_id"].string,
            json["chatgptAccountId"].string,
            json["account_id"].string,
            json["accountId"].string,
            json["nolon"]["account"]["id"].string
        ]
        let accountID = accountIDCandidates
            .compactMap { $0?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        var plan = (json["plan"].string
            ?? json["subscription"]["plan"].string
            ?? json["account"]["plan"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if plan?.isEmpty == true { plan = nil }

        if plan == nil,
           let idToken = (json["tokens"]["id_token"].string
               ?? json["tokens"]["idToken"].string
               ?? json["id_token"].string
               ?? json["idToken"].string
           )?.trimmingCharacters(in: .whitespacesAndNewlines),
           let payload = decodeJWTPayloadJSON(idToken)
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

        let (lastLoginAt, lastSyncSucceededAt, lastSyncFailedAt, lastSyncFailureMessage) = readSyncMetadata(json: json)

        return CodexAuthSummary(
            email: email,
            accountID: accountID,
            apiKeySuffix: suffix,
            plan: plan,
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
            ?? json["profile"]["email"].string
            ?? json["nolon"]["account"]["email"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if email?.isEmpty == true { email = nil }

        if email == nil,
           let idToken = (json["tokens"]["id_token"].string
               ?? json["tokens"]["idToken"].string
               ?? json["id_token"].string
               ?? json["idToken"].string
           )?.trimmingCharacters(in: .whitespacesAndNewlines),
           let payload = decodeJWTPayloadJSON(idToken),
           let derived = (payload["email"].string
               ?? payload["https://api.openai.com/profile"]["email"].string
               ?? payload["profile"]["email"].string
           )?.trimmingCharacters(in: .whitespacesAndNewlines),
           !derived.isEmpty
        {
            email = derived
        }

        let apiKey = (json["OPENAI_API_KEY"].string
            ?? json["openai_api_key"].string
            ?? json["api_key"].string
            ?? json["apiKey"].string
            ?? json["token"].string
            ?? json["access_token"].string
            ?? json["tokens"]["access_token"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountIDCandidates: [String?] = [
            json["account"]["id"].string,
            json["tokens"]["account_id"].string,
            json["tokens"]["accountId"].string,
            json["chatgpt_account_id"].string,
            json["chatgptAccountId"].string,
            json["account_id"].string,
            json["accountId"].string,
            json["nolon"]["account"]["id"].string
        ]
        let accountID = accountIDCandidates
            .compactMap { $0?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        var plan = (json["plan"].string
            ?? json["subscription"]["plan"].string
            ?? json["account"]["plan"].string
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if plan?.isEmpty == true { plan = nil }

        if plan == nil,
           let idToken = (json["tokens"]["id_token"].string
               ?? json["tokens"]["idToken"].string
               ?? json["id_token"].string
               ?? json["idToken"].string
           )?.trimmingCharacters(in: .whitespacesAndNewlines),
           let payload = decodeJWTPayloadJSON(idToken)
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

        let (lastLoginAt, lastSyncSucceededAt, lastSyncFailedAt, lastSyncFailureMessage) = readSyncMetadata(json: json)

        return CodexAuthSummary(
            email: email,
            accountID: accountID,
            apiKeySuffix: suffix,
            plan: plan,
            lastLoginAt: lastLoginAt,
            lastSyncSucceededAt: lastSyncSucceededAt,
            lastSyncFailedAt: lastSyncFailedAt,
            lastSyncFailureMessage: lastSyncFailureMessage
        )
    }
}

private extension CodexAuthSummary {
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
