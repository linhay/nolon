import Foundation
import TOML

public enum CodexGeneratedFilesError: LocalizedError, Sendable, Equatable {
    case invalidUTF8
    case invalidJSON(String)
    case invalidTOML(String)
    case invalidJWT

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Invalid UTF-8 content."
        case let .invalidJSON(message):
            return "Invalid JSON content: \(message)"
        case let .invalidTOML(message):
            return "Invalid TOML content: \(message)"
        case .invalidJWT:
            return "Invalid JWT token format."
        }
    }
}

public enum CodexJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: CodexJSONValue])
    case array([CodexJSONValue])
    case null

    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        if case let .number(value) = self { return Int(value) }
        return nil
    }

    public var objectValue: [String: CodexJSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: CodexJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([CodexJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                CodexJSONValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }

    public func encode(to encoder: Encoder) throws {
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

// MARK: - auth.json

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

// MARK: - history.jsonl

public struct CodexHistoryEntry: Sendable, Equatable, Codable {
    public let sessionID: String
    public let timestamp: UInt64
    public let text: String

    public init(sessionID: String, timestamp: UInt64, text: String) {
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.text = text
    }
}

// MARK: - config.toml / managed_config.toml

public struct CodexConfigToml: Sendable, Equatable, Codable {
    public struct SandboxWorkspaceWrite: Sendable, Equatable, Codable {
        public let writableRoots: [String]?
        public let networkAccess: Bool?

        enum CodingKeys: String, CodingKey {
            case writableRoots = "writable_roots"
            case networkAccess = "network_access"
        }
    }

    public struct History: Sendable, Equatable, Codable {
        public let persistence: String?
        public let maxBytes: Int?

        enum CodingKeys: String, CodingKey {
            case persistence
            case maxBytes = "max_bytes"
        }
    }

    public struct McpServer: Sendable, Equatable, Codable {
        public let type: String?
        public let command: String?
        public let args: [String]?
        public let env: [String: String]?
        public let url: String?
        public let enabled: Bool?
        public let startupTimeoutSec: Int?
        public let toolTimeoutSec: Int?
        public let bearerTokenEnvVar: String?
        public let headers: [String: String]?

        enum CodingKeys: String, CodingKey {
            case type
            case command
            case args
            case env
            case url
            case enabled
            case startupTimeoutSec = "startup_timeout_sec"
            case toolTimeoutSec = "tool_timeout_sec"
            case bearerTokenEnvVar = "bearer_token_env_var"
            case headers
        }
    }

    public struct Profile: Sendable, Equatable, Codable {
        public let model: String?
        public let approvalPolicy: String?
        public let sandboxMode: String?
        public let mcpServers: [String: McpServer]?

        enum CodingKeys: String, CodingKey {
            case model
            case approvalPolicy = "approval_policy"
            case sandboxMode = "sandbox_mode"
            case mcpServers = "mcp_servers"
        }
    }

    public let model: String?
    public let modelProvider: String?
    public let profile: String?
    public let approvalPolicy: String?
    public let sandboxMode: String?
    public let sandboxWorkspaceWrite: SandboxWorkspaceWrite?
    public let chatgptBaseURL: String?
    public let features: [String: Bool]?
    public let history: History?
    public let mcpServers: [String: McpServer]
    public let profiles: [String: Profile]

    enum CodingKeys: String, CodingKey {
        case model
        case modelProvider = "model_provider"
        case profile
        case approvalPolicy = "approval_policy"
        case sandboxMode = "sandbox_mode"
        case sandboxWorkspaceWrite = "sandbox_workspace_write"
        case chatgptBaseURL = "chatgpt_base_url"
        case features
        case history
        case mcpServers = "mcp_servers"
        case profiles
    }

    public init(
        model: String? = nil,
        modelProvider: String? = nil,
        profile: String? = nil,
        approvalPolicy: String? = nil,
        sandboxMode: String? = nil,
        sandboxWorkspaceWrite: SandboxWorkspaceWrite? = nil,
        chatgptBaseURL: String? = nil,
        features: [String: Bool]? = nil,
        history: History? = nil,
        mcpServers: [String: McpServer] = [:],
        profiles: [String: Profile] = [:]
    ) {
        self.model = model
        self.modelProvider = modelProvider
        self.profile = profile
        self.approvalPolicy = approvalPolicy
        self.sandboxMode = sandboxMode
        self.sandboxWorkspaceWrite = sandboxWorkspaceWrite
        self.chatgptBaseURL = chatgptBaseURL
        self.features = features
        self.history = history
        self.mcpServers = mcpServers
        self.profiles = profiles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.modelProvider = try container.decodeIfPresent(String.self, forKey: .modelProvider)
        self.profile = try container.decodeIfPresent(String.self, forKey: .profile)
        self.approvalPolicy = try container.decodeIfPresent(String.self, forKey: .approvalPolicy)
        self.sandboxMode = try container.decodeIfPresent(String.self, forKey: .sandboxMode)
        self.sandboxWorkspaceWrite = try container.decodeIfPresent(SandboxWorkspaceWrite.self, forKey: .sandboxWorkspaceWrite)
        self.chatgptBaseURL = try container.decodeIfPresent(String.self, forKey: .chatgptBaseURL)
        self.features = try container.decodeIfPresent([String: Bool].self, forKey: .features)
        self.history = try container.decodeIfPresent(History.self, forKey: .history)
        self.mcpServers = try container.decodeIfPresent([String: McpServer].self, forKey: .mcpServers) ?? [:]
        self.profiles = try container.decodeIfPresent([String: Profile].self, forKey: .profiles) ?? [:]
    }
}

// MARK: - rollout sessions

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
    }

    public struct ResponseItem: Sendable, Equatable {
        public enum Content: Sendable, Equatable {
            case inputText(String)
            case outputText(String)
            case inputImage(String)
            case other(type: String, raw: CodexJSONValue?)
        }

        public enum Kind: Sendable, Equatable {
            case message(role: String?, content: [Content], phase: String?)
            case functionCall(name: String?, arguments: String?, callID: String?)
            case functionCallOutput(callID: String?, output: CodexJSONValue?)
            case localShellCall(status: String?, action: CodexJSONValue?)
            case customToolCall(name: String?, callID: String?, input: String?)
            case customToolCallOutput(callID: String?, output: String?)
            case reasoning(summary: CodexJSONValue?, content: CodexJSONValue?)
            case webSearchCall(status: String?, action: CodexJSONValue?)
            case compaction(encryptedContent: String?)
            case ghostSnapshot(ghostCommit: CodexJSONValue?)
            case other(type: String, raw: CodexJSONValue?)
        }

        public let kind: Kind
    }

    public struct EventMessage: Sendable, Equatable {
        public struct UserMessage: Sendable, Equatable {
            public let message: String?
            public let images: [String]?
            public let localImages: [String]
            public let textElements: CodexJSONValue?
        }

        public enum Kind: Sendable, Equatable {
            case tokenCount(TokenCount)
            case userMessage(UserMessage)
            case agentMessage(String?)
            case error(String?)
            case warning(String?)
            case turnStarted(modelContextWindow: Int?)
            case turnComplete(lastAgentMessage: String?)
            case other(type: String, payload: CodexJSONValue?)
        }

        public let kind: Kind
    }

    public struct CompactedItem: Sendable, Equatable {
        public let message: String?
        public let replacementHistory: [ResponseItem]?
    }

    public enum Item: Sendable, Equatable {
        case sessionMeta(SessionMetaLine)
        case responseItem(ResponseItem)
        case compacted(CompactedItem)
        case turnContext(TurnContext)
        case eventMsg(EventMessage)
        case tokenCount(TokenCount)
        case other(type: String)
    }

    public let timestamp: String?
    public let item: Item
}

public struct CodexRolloutFile: Sendable, Equatable {
    public let path: String
    public let lines: [CodexRolloutLine]

    public init(path: String, lines: [CodexRolloutLine]) {
        self.path = path
        self.lines = lines
    }
}

public enum CodexGeneratedFilesParser {
    // MARK: auth

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

    // MARK: history

    public static func parseHistoryLine(data: Data) throws -> CodexHistoryEntry {
        struct Raw: Decodable {
            let sessionID: String?
            let conversationID: String?
            let timestamp: UInt64
            let text: String

            enum CodingKeys: String, CodingKey {
                case sessionID = "session_id"
                case conversationID = "conversation_id"
                case timestamp = "ts"
                case text
            }
        }

        let raw: Raw
        do {
            raw = try JSONDecoder().decode(Raw.self, from: data)
        } catch {
            throw CodexGeneratedFilesError.invalidJSON(error.localizedDescription)
        }
        let sessionID = raw.sessionID ?? raw.conversationID ?? ""
        return CodexHistoryEntry(sessionID: sessionID, timestamp: raw.timestamp, text: raw.text)
    }

    public static func parseHistoryLines(data: Data) throws -> [CodexHistoryEntry] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CodexGeneratedFilesError.invalidUTF8
        }
        return try text
            .split(whereSeparator: \.isNewline)
            .filter { !$0.isEmpty }
            .map { line in
                guard let lineData = String(line).data(using: .utf8) else {
                    throw CodexGeneratedFilesError.invalidUTF8
                }
                return try parseHistoryLine(data: lineData)
            }
    }

    // MARK: config

    public static func parseConfigToml(data: Data) throws -> CodexConfigToml {
        do {
            return try TOMLDecoder().decode(CodexConfigToml.self, from: data)
        } catch {
            throw CodexGeneratedFilesError.invalidTOML(error.localizedDescription)
        }
    }

    // MARK: rollout

    public static func parseRolloutLine(data: Data) throws -> CodexRolloutLine {
        struct RawLine: Decodable {
            let timestamp: String?
            let type: String
            let payload: CodexJSONValue?
        }

        let raw: RawLine
        do {
            raw = try JSONDecoder().decode(RawLine.self, from: data)
        } catch {
            throw CodexGeneratedFilesError.invalidJSON(error.localizedDescription)
        }

        switch raw.type {
        case "session_meta":
            return .init(timestamp: raw.timestamp, item: .sessionMeta(parseSessionMeta(payload: raw.payload)))
        case "response_item":
            return .init(timestamp: raw.timestamp, item: .responseItem(parseResponseItem(payload: raw.payload)))
        case "compacted":
            return .init(timestamp: raw.timestamp, item: .compacted(parseCompacted(payload: raw.payload)))
        case "turn_context":
            return .init(timestamp: raw.timestamp, item: .turnContext(parseTurnContext(payload: raw.payload)))
        case "event_msg":
            if let tokenCount = parseTokenCountFromEventMessage(payload: raw.payload) {
                return .init(timestamp: raw.timestamp, item: .tokenCount(tokenCount))
            }
            return .init(timestamp: raw.timestamp, item: .eventMsg(parseEventMessage(payload: raw.payload)))
        case "token_count":
            let tokenCount = parseTokenCount(payload: raw.payload?.objectValue ?? [:], fallbackModel: nil)
            return .init(timestamp: raw.timestamp, item: .tokenCount(tokenCount))
        default:
            return .init(timestamp: raw.timestamp, item: .other(type: raw.type))
        }
    }

    public static func parseRolloutLine(text: String) throws -> CodexRolloutLine {
        guard let data = text.data(using: .utf8) else {
            throw CodexGeneratedFilesError.invalidUTF8
        }
        return try parseRolloutLine(data: data)
    }

    public static func parseRolloutLines(data: Data) throws -> [CodexRolloutLine] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CodexGeneratedFilesError.invalidUTF8
        }
        return try text
            .split(whereSeparator: \.isNewline)
            .filter { !$0.isEmpty }
            .map { line in
                try parseRolloutLine(text: String(line))
            }
    }

    public static func loadRolloutFiles(
        codexHome: URL,
        includeArchived: Bool = true
    ) throws -> [CodexRolloutFile] {
        let sessionsRoot = codexHome.appendingPathComponent("sessions", isDirectory: true)
        var roots = [sessionsRoot]
        if includeArchived {
            roots.append(codexHome.appendingPathComponent("archived_sessions", isDirectory: true))
        }

        var files: [CodexRolloutFile] = []
        for root in roots {
            let lineFiles = findJSONLFiles(root: root)
            for file in lineFiles {
                let data = try Data(contentsOf: file)
                let lines = (try? parseRolloutLines(data: data)) ?? []
                files.append(.init(path: file.path, lines: lines))
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    // MARK: internals

    private static func parseSessionMeta(payload: CodexJSONValue?) -> CodexRolloutLine.SessionMetaLine {
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

    private static func parseTurnContext(payload: CodexJSONValue?) -> CodexRolloutLine.TurnContext {
        let object = payload?.objectValue ?? [:]
        return .init(
            cwd: object["cwd"]?.stringValue,
            approvalPolicy: object["approval_policy"]?.stringValue,
            sandboxPolicy: object["sandbox_policy"]?.stringValue,
            model: object["model"]?.stringValue
        )
    }

    private static func parseCompacted(payload: CodexJSONValue?) -> CodexRolloutLine.CompactedItem {
        let object = payload?.objectValue ?? [:]
        let historyValues = object["replacement_history"]?.arrayValue ?? []
        let history = historyValues.map { parseResponseItem(payload: $0) }
        return .init(
            message: object["message"]?.stringValue,
            replacementHistory: history.isEmpty ? nil : history
        )
    }

    private static func parseResponseItem(payload: CodexJSONValue?) -> CodexRolloutLine.ResponseItem {
        let object = payload?.objectValue ?? [:]
        let type = object["type"]?.stringValue ?? "unknown"

        func parseContent(_ value: CodexJSONValue?) -> [CodexRolloutLine.ResponseItem.Content] {
            guard let items = value?.arrayValue else { return [] }
            return items.map { item in
                let raw = item.objectValue ?? [:]
                let contentType = raw["type"]?.stringValue ?? "unknown"
                switch contentType {
                case "input_text":
                    return .inputText(raw["text"]?.stringValue ?? "")
                case "output_text":
                    return .outputText(raw["text"]?.stringValue ?? "")
                case "input_image":
                    return .inputImage(raw["image_url"]?.stringValue ?? "")
                default:
                    return .other(type: contentType, raw: item)
                }
            }
        }

        let kind: CodexRolloutLine.ResponseItem.Kind
        switch type {
        case "message":
            kind = .message(
                role: object["role"]?.stringValue,
                content: parseContent(object["content"]),
                phase: object["phase"]?.stringValue
            )
        case "function_call":
            kind = .functionCall(
                name: object["name"]?.stringValue,
                arguments: object["arguments"]?.stringValue,
                callID: object["call_id"]?.stringValue
            )
        case "function_call_output":
            kind = .functionCallOutput(
                callID: object["call_id"]?.stringValue,
                output: object["output"]
            )
        case "local_shell_call":
            kind = .localShellCall(
                status: object["status"]?.stringValue,
                action: object["action"]
            )
        case "custom_tool_call":
            kind = .customToolCall(
                name: object["name"]?.stringValue,
                callID: object["call_id"]?.stringValue,
                input: object["input"]?.stringValue
            )
        case "custom_tool_call_output":
            kind = .customToolCallOutput(
                callID: object["call_id"]?.stringValue,
                output: object["output"]?.stringValue
            )
        case "reasoning":
            kind = .reasoning(summary: object["summary"], content: object["content"])
        case "web_search_call":
            kind = .webSearchCall(
                status: object["status"]?.stringValue,
                action: object["action"]
            )
        case "compaction", "compaction_summary":
            kind = .compaction(encryptedContent: object["encrypted_content"]?.stringValue)
        case "ghost_snapshot":
            kind = .ghostSnapshot(ghostCommit: object["ghost_commit"])
        default:
            kind = .other(type: type, raw: payload)
        }
        return .init(kind: kind)
    }

    private static func parseEventMessage(payload: CodexJSONValue?) -> CodexRolloutLine.EventMessage {
        let object = payload?.objectValue ?? [:]
        let type = object["type"]?.stringValue ?? "unknown"

        let kind: CodexRolloutLine.EventMessage.Kind
        switch type {
        case "token_count":
            kind = .tokenCount(parseTokenCount(payload: object, fallbackModel: nil))
        case "user_message":
            let localImages = object["local_images"]?.arrayValue?.compactMap { $0.stringValue } ?? []
            let images = object["images"]?.arrayValue?.compactMap { $0.stringValue }
            kind = .userMessage(.init(
                message: object["message"]?.stringValue,
                images: images,
                localImages: localImages,
                textElements: object["text_elements"]
            ))
        case "agent_message":
            kind = .agentMessage(object["message"]?.stringValue)
        case "error":
            kind = .error(object["message"]?.stringValue)
        case "warning":
            kind = .warning(object["message"]?.stringValue)
        case "task_started", "turn_started":
            kind = .turnStarted(modelContextWindow: object["model_context_window"]?.intValue)
        case "task_complete", "turn_complete":
            kind = .turnComplete(lastAgentMessage: object["last_agent_message"]?.stringValue)
        default:
            kind = .other(type: type, payload: payload)
        }

        return .init(kind: kind)
    }

    private static func parseTokenCountFromEventMessage(payload: CodexJSONValue?) -> CodexRolloutLine.TokenCount? {
        let object = payload?.objectValue ?? [:]
        if object["type"]?.stringValue == "token_count" {
            return parseTokenCount(payload: object, fallbackModel: nil)
        }
        if let nested = object["payload"]?.objectValue, nested["type"]?.stringValue == "token_count" {
            return parseTokenCount(payload: nested, fallbackModel: nil)
        }
        return nil
    }

    private static func parseTokenCount(payload: [String: CodexJSONValue], fallbackModel: String?) -> CodexRolloutLine.TokenCount {
        let info = payload["info"]?.objectValue
        let model = info?["model"]?.stringValue
            ?? info?["model_name"]?.stringValue
            ?? payload["model"]?.stringValue
            ?? fallbackModel

        let total = parseTokenUsage(info?["total_token_usage"]?.objectValue)
        let last = parseTokenUsage(info?["last_token_usage"]?.objectValue)
        return .init(model: model, totalUsage: total, lastUsage: last)
    }

    private static func parseTokenUsage(_ object: [String: CodexJSONValue]?) -> CodexRolloutLine.TokenUsage? {
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
              let payload = try? JSONDecoder().decode([String: CodexJSONValue].self, from: payloadData)
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

    private static func findJSONLFiles(root: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        guard let enumerator else { return [] }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "jsonl" else { continue }
            files.append(fileURL)
        }
        return files
    }
}

private extension CodexJSONValue {
    var arrayValue: [CodexJSONValue]? {
        if case let .array(values) = self { return values }
        return nil
    }
}
