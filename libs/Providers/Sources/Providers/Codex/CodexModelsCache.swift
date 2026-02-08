import Foundation

public enum CodexModelsCacheError: LocalizedError, Sendable, Equatable {
    case fileNotFound(String)
    case unreadable(String)
    case invalidJSON(String)

    public var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            "Codex models cache not found at \(path)"
        case let .unreadable(message):
            "Failed to read Codex models cache: \(message)"
        case let .invalidJSON(message):
            "Failed to decode Codex models cache: \(message)"
        }
    }
}

public struct CodexModelsCache: Decodable, Sendable, Equatable {
    public let fetchedAt: Date
    public let etag: String?
    public let clientVersion: String?
    public let models: [Model]

    public init(fetchedAt: Date, etag: String?, clientVersion: String?, models: [Model]) {
        self.fetchedAt = fetchedAt
        self.etag = etag
        self.clientVersion = clientVersion
        self.models = models
    }

    enum CodingKeys: String, CodingKey {
        case fetchedAt = "fetched_at"
        case etag
        case clientVersion = "client_version"
        case models
    }

    public struct Model: Decodable, Sendable, Equatable {
        public let slug: String
        public let displayName: String
        public let description: String?
        public let defaultReasoningLevel: String?
        public let supportedReasoningLevels: [ReasoningLevel]
        public let shellType: String?
        public let visibility: String?
        public let minimalClientVersion: [Int]?
        public let supportedInAPI: Bool?
        public let priority: Int?
        public let upgrade: Upgrade?
        public let baseInstructions: String?
        public let modelMessages: ModelMessages?
        public let supportsReasoningSummaries: Bool?
        public let supportsVerbosity: Bool?
        public let defaultVerbosity: String?
        public let applyPatchToolType: String?
        public let truncationPolicy: TruncationPolicy?
        public let supportsParallelToolCalls: Bool?
        public let contextWindow: Int?
        public let effectiveContextWindowPercent: Int?
        public let experimentalSupportedTools: [String]?
        public let inputModalities: [String]?

        enum CodingKeys: String, CodingKey {
            case slug
            case displayName = "display_name"
            case description
            case defaultReasoningLevel = "default_reasoning_level"
            case supportedReasoningLevels = "supported_reasoning_levels"
            case shellType = "shell_type"
            case visibility
            case minimalClientVersion = "minimal_client_version"
            case supportedInAPI = "supported_in_api"
            case priority
            case upgrade
            case baseInstructions = "base_instructions"
            case modelMessages = "model_messages"
            case supportsReasoningSummaries = "supports_reasoning_summaries"
            case supportsVerbosity = "supports_verbosity"
            case supportVerbosity = "support_verbosity"
            case defaultVerbosity = "default_verbosity"
            case applyPatchToolType = "apply_patch_tool_type"
            case truncationPolicy = "truncation_policy"
            case supportsParallelToolCalls = "supports_parallel_tool_calls"
            case contextWindow = "context_window"
            case effectiveContextWindowPercent = "effective_context_window_percent"
            case experimentalSupportedTools = "experimental_supported_tools"
            case inputModalities = "input_modalities"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.slug = try container.decode(String.self, forKey: .slug)
            self.displayName = try container.decode(String.self, forKey: .displayName)
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
            self.defaultReasoningLevel = try container.decodeIfPresent(String.self, forKey: .defaultReasoningLevel)
            self.supportedReasoningLevels = try container.decodeIfPresent([ReasoningLevel].self, forKey: .supportedReasoningLevels) ?? []
            self.shellType = try container.decodeIfPresent(String.self, forKey: .shellType)
            self.visibility = try container.decodeIfPresent(String.self, forKey: .visibility)
            self.minimalClientVersion = try container.decodeIfPresent([Int].self, forKey: .minimalClientVersion)
            self.supportedInAPI = try container.decodeIfPresent(Bool.self, forKey: .supportedInAPI)
            self.priority = try container.decodeIfPresent(Int.self, forKey: .priority)
            self.upgrade = try container.decodeIfPresent(Upgrade.self, forKey: .upgrade)
            self.baseInstructions = try container.decodeIfPresent(String.self, forKey: .baseInstructions)
            self.modelMessages = try container.decodeIfPresent(ModelMessages.self, forKey: .modelMessages)
            self.supportsReasoningSummaries = try container.decodeIfPresent(Bool.self, forKey: .supportsReasoningSummaries)
            self.supportsVerbosity =
                try container.decodeIfPresent(Bool.self, forKey: .supportsVerbosity)
                ?? (try container.decodeIfPresent(Bool.self, forKey: .supportVerbosity))
            self.defaultVerbosity = try container.decodeIfPresent(String.self, forKey: .defaultVerbosity)
            self.applyPatchToolType = try container.decodeIfPresent(String.self, forKey: .applyPatchToolType)
            self.truncationPolicy = try container.decodeIfPresent(TruncationPolicy.self, forKey: .truncationPolicy)
            self.supportsParallelToolCalls = try container.decodeIfPresent(Bool.self, forKey: .supportsParallelToolCalls)
            self.contextWindow = try container.decodeIfPresent(Int.self, forKey: .contextWindow)
            self.effectiveContextWindowPercent = try container.decodeIfPresent(Int.self, forKey: .effectiveContextWindowPercent)
            self.experimentalSupportedTools = try container.decodeIfPresent([String].self, forKey: .experimentalSupportedTools)
            self.inputModalities = try container.decodeIfPresent([String].self, forKey: .inputModalities)
        }
    }

    public struct ReasoningLevel: Decodable, Sendable, Equatable {
        public let effort: String
        public let description: String

        public init(effort: String, description: String) {
            self.effort = effort
            self.description = description
        }
    }

    public struct Upgrade: Decodable, Sendable, Equatable {
        public let id: String?
        public let slug: String?

        public init(id: String?, slug: String?) {
            self.id = id
            self.slug = slug
        }
    }

    public struct ModelMessages: Decodable, Sendable, Equatable {
        public let instructionsTemplate: String?
        public let instructionsVariables: [String: String]

        enum CodingKeys: String, CodingKey {
            case instructionsTemplate = "instructions_template"
            case instructionsVariables = "instructions_variables"
        }

        public init(instructionsTemplate: String?, instructionsVariables: [String: String]) {
            self.instructionsTemplate = instructionsTemplate
            self.instructionsVariables = instructionsVariables
        }
    }

    public struct TruncationPolicy: Decodable, Sendable, Equatable {
        public let mode: String
        public let limit: Int?

        public init(mode: String, limit: Int?) {
            self.mode = mode
            self.limit = limit
        }
    }
}

extension CodexModelsCache {
    public static func decode(from data: Data) throws -> CodexModelsCache {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = Self.parseDate(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported fetched_at date: \(raw)")
        }
        return try decoder.decode(CodexModelsCache.self, from: data)
    }

    public static func load(from fileURL: URL) throws -> CodexModelsCache {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CodexModelsCacheError.fileNotFound(fileURL.path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw CodexModelsCacheError.unreadable(error.localizedDescription)
        }
        do {
            return try Self.decode(from: data)
        } catch {
            throw CodexModelsCacheError.invalidJSON(error.localizedDescription)
        }
    }

    private static func parseDate(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: raw)
    }
}
