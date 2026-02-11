import Foundation

public enum CodexGeneratedFilesError: LocalizedError, Sendable, Equatable {
    case invalidUTF8
    case invalidJSON(String)
    case invalidJWT

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Invalid UTF-8 content."
        case let .invalidJSON(message):
            return "Invalid JSON content: \(message)"
        case .invalidJWT:
            return "Invalid JWT token format."
        }
    }
}

public struct CodexAuthFile: Sendable, Equatable {
    public enum AuthMode: String, Sendable, Equatable, Codable {
        case chatgpt = "chatgpt"
        case apiKey = "apikey"
        case chatgptAuthTokens = "chatgptAuthTokens"
    }

    public struct Tokens: Sendable, Equatable, Codable {
        public let idTokenRaw: String?
        public let accessToken: String?
        public let refreshToken: String?
        public let accountID: String?
        public let idTokenClaims: IDTokenClaims?

        public init(
            idTokenRaw: String?,
            accessToken: String?,
            refreshToken: String?,
            accountID: String?,
            idTokenClaims: IDTokenClaims?
        ) {
            self.idTokenRaw = idTokenRaw
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.accountID = accountID
            self.idTokenClaims = idTokenClaims
        }
    }

    public struct IDTokenClaims: Sendable, Equatable, Codable {
        public let email: String?
        public let chatgptPlanType: String?
        public let chatgptUserID: String?
        public let chatgptAccountID: String?

        public init(
            email: String?,
            chatgptPlanType: String?,
            chatgptUserID: String?,
            chatgptAccountID: String?
        ) {
            self.email = email
            self.chatgptPlanType = chatgptPlanType
            self.chatgptUserID = chatgptUserID
            self.chatgptAccountID = chatgptAccountID
        }
    }

    public let authMode: AuthMode?
    public let openAIAPIKey: String?
    public let tokens: Tokens?
    public let lastRefresh: Date?

    public init(authMode: AuthMode?, openAIAPIKey: String?, tokens: Tokens?, lastRefresh: Date?) {
        self.authMode = authMode
        self.openAIAPIKey = openAIAPIKey
        self.tokens = tokens
        self.lastRefresh = lastRefresh
    }
}

public struct CodexRolloutLine: Sendable, Equatable {
    public struct SessionMetaLine: Sendable, Equatable {
        public struct GitInfo: Sendable, Equatable {
            public let commitHash: String?
            public let branch: String?
            public let repositoryURL: String?
        }

        public let id: String?
        public let forkedFromID: String?
        public let timestamp: String?
        public let cwd: String?
        public let originator: String?
        public let cliVersion: String?
        public let source: String?
        public let modelProvider: String?
        public let git: GitInfo?
    }

    public struct TurnContext: Sendable, Equatable {
        public let cwd: String?
        public let approvalPolicy: String?
        public let sandboxPolicy: String?
        public let model: String?
    }

    public struct TokenUsage: Sendable, Equatable {
        public let inputTokens: Int
        public let cachedInputTokens: Int
        public let outputTokens: Int
        public let totalTokens: Int

        public init(inputTokens: Int, cachedInputTokens: Int, outputTokens: Int, totalTokens: Int) {
            self.inputTokens = inputTokens
            self.cachedInputTokens = cachedInputTokens
            self.outputTokens = outputTokens
            self.totalTokens = totalTokens
        }
    }

    public struct TokenCount: Sendable, Equatable {
        public let model: String?
        public let totalUsage: TokenUsage?
        public let lastUsage: TokenUsage?

        public init(model: String?, totalUsage: TokenUsage?, lastUsage: TokenUsage?) {
            self.model = model
            self.totalUsage = totalUsage
            self.lastUsage = lastUsage
        }
    }

    public enum Item: Sendable, Equatable {
        case sessionMeta(SessionMetaLine)
        case turnContext(TurnContext)
        case tokenCount(TokenCount)
        case other(type: String)
    }

    public let timestamp: String?
    public let item: Item
}

public enum CodexGeneratedFilesParser {
    public static func parseAuth(data: Data) throws -> CodexAuthFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct AuthRaw: Decodable {
            let authMode: String?
            let openAIAPIKey: String?
            let tokens: TokensRaw?
            let lastRefresh: Date?

            struct TokensRaw: Decodable {
                let idToken: String?
                let accessToken: String?
                let refreshToken: String?
                let accountID: String?

                enum CodingKeys: String, CodingKey {
                    case idToken = "id_token"
                    case accessToken = "access_token"
                    case refreshToken = "refresh_token"
                    case accountID = "account_id"
                }
            }

            enum CodingKeys: String, CodingKey {
                case authMode = "auth_mode"
                case openAIAPIKey = "OPENAI_API_KEY"
                case tokens
                case lastRefresh = "last_refresh"
            }
        }

        let raw: AuthRaw
        do {
            raw = try decoder.decode(AuthRaw.self, from: data)
        } catch {
            throw CodexGeneratedFilesError.invalidJSON(error.localizedDescription)
        }

        let mode = raw.authMode.flatMap(CodexAuthFile.AuthMode.init(rawValue:))
        let claims = try raw.tokens?.idToken.map(parseIDTokenClaims(jwt:))
        let tokens = raw.tokens.map {
            CodexAuthFile.Tokens(
                idTokenRaw: $0.idToken,
                accessToken: $0.accessToken,
                refreshToken: $0.refreshToken,
                accountID: $0.accountID,
                idTokenClaims: claims ?? nil
            )
        }
        return CodexAuthFile(authMode: mode, openAIAPIKey: raw.openAIAPIKey, tokens: tokens, lastRefresh: raw.lastRefresh)
    }

    public static func parseAuth(jsonString: String) throws -> CodexAuthFile {
        guard let data = jsonString.data(using: .utf8) else {
            throw CodexGeneratedFilesError.invalidUTF8
        }
        return try parseAuth(data: data)
    }

    public static func parseRolloutLine(data: Data) throws -> CodexRolloutLine {
        struct RawLine: Decodable {
            let timestamp: String?
            let type: String
            let payload: JSONValue?
        }

        let raw: RawLine
        do {
            raw = try JSONDecoder().decode(RawLine.self, from: data)
        } catch {
            throw CodexGeneratedFilesError.invalidJSON(error.localizedDescription)
        }

        switch raw.type {
        case "session_meta":
            let meta = parseSessionMeta(payload: raw.payload)
            return CodexRolloutLine(timestamp: raw.timestamp, item: .sessionMeta(meta))
        case "turn_context":
            let context = parseTurnContext(payload: raw.payload)
            return CodexRolloutLine(timestamp: raw.timestamp, item: .turnContext(context))
        case "event_msg":
            if let tokenCount = parseTokenCountFromEventMessage(payload: raw.payload) {
                return CodexRolloutLine(timestamp: raw.timestamp, item: .tokenCount(tokenCount))
            }
            return CodexRolloutLine(timestamp: raw.timestamp, item: .other(type: raw.type))
        case "token_count":
            let tokenCount = parseTokenCount(payload: raw.payload?.objectValue ?? [:], fallbackModel: nil)
            return CodexRolloutLine(timestamp: raw.timestamp, item: .tokenCount(tokenCount))
        default:
            return CodexRolloutLine(timestamp: raw.timestamp, item: .other(type: raw.type))
        }
    }

    public static func parseRolloutLine(text: String) throws -> CodexRolloutLine {
        guard let data = text.data(using: .utf8) else {
            throw CodexGeneratedFilesError.invalidUTF8
        }
        return try parseRolloutLine(data: data)
    }

    private static func parseSessionMeta(payload: JSONValue?) -> CodexRolloutLine.SessionMetaLine {
        let object = payload?.objectValue ?? [:]
        let gitObject = object["git"]?.objectValue
        let git: CodexRolloutLine.SessionMetaLine.GitInfo? = gitObject.map {
            .init(
                commitHash: $0["commit_hash"]?.stringValue,
                branch: $0["branch"]?.stringValue,
                repositoryURL: $0["repository_url"]?.stringValue
            )
        }
        return .init(
            id: object["id"]?.stringValue,
            forkedFromID: object["forked_from_id"]?.stringValue,
            timestamp: object["timestamp"]?.stringValue,
            cwd: object["cwd"]?.stringValue,
            originator: object["originator"]?.stringValue,
            cliVersion: object["cli_version"]?.stringValue,
            source: object["source"]?.stringValue,
            modelProvider: object["model_provider"]?.stringValue,
            git: git
        )
    }

    private static func parseTurnContext(payload: JSONValue?) -> CodexRolloutLine.TurnContext {
        let object = payload?.objectValue ?? [:]
        return .init(
            cwd: object["cwd"]?.stringValue,
            approvalPolicy: object["approval_policy"]?.stringValue,
            sandboxPolicy: object["sandbox_policy"]?.stringValue,
            model: object["model"]?.stringValue
        )
    }

    private static func parseTokenCountFromEventMessage(payload: JSONValue?) -> CodexRolloutLine.TokenCount? {
        let object = payload?.objectValue ?? [:]
        if object["type"]?.stringValue == "token_count" {
            return parseTokenCount(payload: object, fallbackModel: nil)
        }
        if let nested = object["payload"]?.objectValue, nested["type"]?.stringValue == "token_count" {
            return parseTokenCount(payload: nested, fallbackModel: nil)
        }
        return nil
    }

    private static func parseTokenCount(payload: [String: JSONValue], fallbackModel: String?) -> CodexRolloutLine.TokenCount {
        let info = payload["info"]?.objectValue
        let model = info?["model"]?.stringValue
            ?? info?["model_name"]?.stringValue
            ?? payload["model"]?.stringValue
            ?? fallbackModel

        let total = parseTokenUsage(info?["total_token_usage"]?.objectValue)
        let last = parseTokenUsage(info?["last_token_usage"]?.objectValue)
        return .init(model: model, totalUsage: total, lastUsage: last)
    }

    private static func parseTokenUsage(_ object: [String: JSONValue]?) -> CodexRolloutLine.TokenUsage? {
        guard let object else { return nil }
        let input = object["input_tokens"]?.intValue ?? 0
        let cached = object["cached_input_tokens"]?.intValue
            ?? object["cache_read_input_tokens"]?.intValue
            ?? 0
        let output = object["output_tokens"]?.intValue ?? 0
        let total = object["total_tokens"]?.intValue ?? max(0, input + output)
        return .init(inputTokens: input, cachedInputTokens: cached, outputTokens: output, totalTokens: total)
    }

    private static func parseIDTokenClaims(jwt: String) throws -> CodexAuthFile.IDTokenClaims {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            throw CodexGeneratedFilesError.invalidJWT
        }
        let payloadPart = String(parts[1])
        guard let payloadData = base64URLDecode(payloadPart),
              let payload = try? JSONDecoder().decode([String: JSONValue].self, from: payloadData)
        else {
            throw CodexGeneratedFilesError.invalidJWT
        }

        let auth = payload["https://api.openai.com/auth"]?.objectValue
        return .init(
            email: payload["email"]?.stringValue ?? payload["https://api.openai.com/profile"]?.objectValue?["email"]?.stringValue,
            chatgptPlanType: auth?["chatgpt_plan_type"]?.stringValue,
            chatgptUserID: auth?["chatgpt_user_id"]?.stringValue ?? auth?["user_id"]?.stringValue,
            chatgptAccountID: auth?["chatgpt_account_id"]?.stringValue
        )
    }

    private static func base64URLDecode(_ raw: String) -> Data? {
        var normalized = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: normalized)
    }
}

private enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case let .number(value) = self { return Int(value) }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
