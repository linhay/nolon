import Foundation

struct CodexAuthDotJson: Codable, Sendable, Hashable {
    var authMode: String?
    var openaiApiKey: String?
    var tokens: CodexTokenData?
    var lastRefresh: Date?

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case openaiApiKey = "OPENAI_API_KEY"
        case tokens
        case lastRefresh = "last_refresh"
    }
}

struct CodexTokenData: Codable, Sendable, Hashable {
    var idToken: String?
    var accessToken: String?
    var refreshToken: String?
    var accountId: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case accountId = "account_id"
    }
}

struct CodexAuthSummary: Sendable, Hashable {
    var email: String?
    var chatgptPlanType: String?
    var apiKeyLast4: String?

    var isEmpty: Bool {
        email == nil && chatgptPlanType == nil && apiKeyLast4 == nil
    }
}

enum CodexAuthDotJsonReader {
    static func readAuth(at url: URL) throws -> CodexAuthDotJson {
        let data = try Data(contentsOf: url)
        return try decodeAuthData(data)
    }

    static func decodeAuthData(_ data: Data) throws -> CodexAuthDotJson {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(CodexAuthDotJson.self, from: data) {
            return decoded
        }
        // Fallback if last_refresh isn't ISO-8601 on disk.
        return try JSONDecoder().decode(CodexAuthDotJson.self, from: data)
    }

    static func summarize(_ auth: CodexAuthDotJson) -> CodexAuthSummary {
        let last4 = auth.openaiApiKey.flatMap { key -> String? in
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 4 else { return nil }
            return String(trimmed.suffix(4))
        }

        let tokenInfo = parseIdTokenPayload(auth.tokens?.idToken)
        return CodexAuthSummary(
            email: tokenInfo.email,
            chatgptPlanType: tokenInfo.chatgptPlanType,
            apiKeyLast4: last4
        )
    }

    private struct IdTokenInfo: Sendable, Hashable {
        var email: String?
        var chatgptPlanType: String?
    }

    private static func parseIdTokenPayload(_ jwt: String?) -> IdTokenInfo {
        guard let jwt else { return IdTokenInfo(email: nil, chatgptPlanType: nil) }
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return IdTokenInfo(email: nil, chatgptPlanType: nil) }
        let payloadB64Url = String(parts[1])
        guard let payloadData = base64UrlDecode(payloadB64Url) else {
            return IdTokenInfo(email: nil, chatgptPlanType: nil)
        }

        guard let json = (try? JSONSerialization.jsonObject(with: payloadData)) as? [String: Any] else {
            return IdTokenInfo(email: nil, chatgptPlanType: nil)
        }

        let email = json["email"] as? String
            ?? ((json["https://api.openai.com/profile"] as? [String: Any])?["email"] as? String)

        let auth = (json["https://api.openai.com/auth"] as? [String: Any]) ?? [:]
        let planType = auth["chatgpt_plan_type"] as? String

        return IdTokenInfo(email: email, chatgptPlanType: planType)
    }

    private static func base64UrlDecode(_ s: String) -> Data? {
        var base64 = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = base64.count % 4
        if pad != 0 {
            base64 += String(repeating: "=", count: 4 - pad)
        }
        return Data(base64Encoded: base64)
    }
}
