import Foundation
import STJSON
import CryptoKit

public struct CodexAuthAccount: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    /// Relative path under `~/.nolon/codex/` (e.g. `auth/work.json`).
    public var relativeAuthPath: String

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date(), relativeAuthPath: String) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.relativeAuthPath = relativeAuthPath
    }

    public static func hashHex(for authJSONString: String) -> String {
        let data = Data(authJSONString.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public struct CodexAuthSummary: Hashable, Sendable {
    public var email: String?
    public var apiKeySuffix: String?
    public var plan: String?

    public static func fromJSONString(_ string: String) -> CodexAuthSummary {
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

        return CodexAuthSummary(email: email,
                               apiKeySuffix: suffix,
                               plan: plan)
    }

    public static func fromJSONData(_ data: Data) -> CodexAuthSummary {
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

        return CodexAuthSummary(email: email,
                               apiKeySuffix: suffix,
                               plan: plan)
    }
}

private extension CodexAuthSummary {
    static func decodeJWTPayloadJSON(_ jwt: String) -> JSON? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        guard let payloadData = base64URLDecode(String(parts[1])) else { return nil }
        return try? JSON(data: payloadData)
    }

    static func base64URLDecode(_ string: String) -> Data? {
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
