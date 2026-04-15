import Foundation
import CryptoKit

public enum ClaudeCredentialType: String, Codable, CaseIterable, Sendable {
    case authToken
    case apiKey
}

public enum ClaudeAccountSource: String, Codable, Sendable {
    case manual
    case migrated
    case ccSwitch
}

public struct ClaudeAccount: Identifiable, Codable, Hashable, Sendable {
    public static let defaultAnthropicModel = ""
    public static let defaultAnthropicReasoningModel = ""
    public static let defaultAnthropicDefaultHaikuModel = ""
    public static let defaultAnthropicDefaultSonnetModel = ""
    public static let defaultAnthropicDefaultOpusModel = ""

    public let id: UUID
    public var name: String
    public var credentialType: ClaudeCredentialType
    public var credentialValue: String
    public var baseURL: String
    public var anthropicModel: String
    public var anthropicReasoningModel: String
    public var anthropicDefaultHaikuModel: String
    public var anthropicDefaultSonnetModel: String
    public var anthropicDefaultOpusModel: String
    public var source: ClaudeAccountSource
    public var usageQuery: CodexHTTPUsageQuery?
    public var createdAt: Date
    public var updatedAt: Date
    public var lastValidatedAt: Date?
    public var lastValidationStatus: Bool?

    public init(
        id: UUID = UUID(),
        name: String,
        credentialType: ClaudeCredentialType,
        credentialValue: String,
        baseURL: String,
        anthropicModel: String = ClaudeAccount.defaultAnthropicModel,
        anthropicReasoningModel: String = ClaudeAccount.defaultAnthropicReasoningModel,
        anthropicDefaultHaikuModel: String = ClaudeAccount.defaultAnthropicDefaultHaikuModel,
        anthropicDefaultSonnetModel: String = ClaudeAccount.defaultAnthropicDefaultSonnetModel,
        anthropicDefaultOpusModel: String = ClaudeAccount.defaultAnthropicDefaultOpusModel,
        source: ClaudeAccountSource,
        usageQuery: CodexHTTPUsageQuery? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastValidatedAt: Date? = nil,
        lastValidationStatus: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.credentialType = credentialType
        self.credentialValue = credentialValue
        self.baseURL = baseURL
        let resolvedModels = Self.resolveModels(
            model: anthropicModel,
            reasoning: anthropicReasoningModel,
            haiku: anthropicDefaultHaikuModel,
            sonnet: anthropicDefaultSonnetModel,
            opus: anthropicDefaultOpusModel,
            smallFast: nil
        )
        self.anthropicModel = resolvedModels.model
        self.anthropicReasoningModel = resolvedModels.reasoning
        self.anthropicDefaultHaikuModel = resolvedModels.haiku
        self.anthropicDefaultSonnetModel = resolvedModels.sonnet
        self.anthropicDefaultOpusModel = resolvedModels.opus
        self.source = source
        self.usageQuery = usageQuery
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastValidatedAt = lastValidatedAt
        self.lastValidationStatus = lastValidationStatus
    }

    public var normalizedBaseURL: String {
        Self.normalized(urlString: baseURL)
    }

    public var credentialFingerprint: String {
        let raw = "\(credentialType.rawValue):\(credentialValue)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func duplicateConflictKey() -> String {
        "\(normalizedBaseURL)|\(credentialFingerprint)"
    }

    public static func normalized(urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return trimmed.lowercased() }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        components?.query = nil
        let normalized = components?.string ?? trimmed
        return normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }

    public static func == (lhs: ClaudeAccount, rhs: ClaudeAccount) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.credentialType == rhs.credentialType &&
        lhs.credentialValue == rhs.credentialValue &&
        lhs.baseURL == rhs.baseURL &&
        lhs.anthropicModel == rhs.anthropicModel &&
        lhs.anthropicReasoningModel == rhs.anthropicReasoningModel &&
        lhs.anthropicDefaultHaikuModel == rhs.anthropicDefaultHaikuModel &&
        lhs.anthropicDefaultSonnetModel == rhs.anthropicDefaultSonnetModel &&
        lhs.anthropicDefaultOpusModel == rhs.anthropicDefaultOpusModel &&
        lhs.source == rhs.source &&
        lhs.usageQuery == rhs.usageQuery &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.lastValidatedAt == rhs.lastValidatedAt &&
        lhs.lastValidationStatus == rhs.lastValidationStatus
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(credentialType)
        hasher.combine(credentialValue)
        hasher.combine(baseURL)
        hasher.combine(anthropicModel)
        hasher.combine(anthropicReasoningModel)
        hasher.combine(anthropicDefaultHaikuModel)
        hasher.combine(anthropicDefaultSonnetModel)
        hasher.combine(anthropicDefaultOpusModel)
        hasher.combine(source)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
        hasher.combine(lastValidatedAt)
        hasher.combine(lastValidationStatus)
        hasher.combine(usageQuery.map { String(describing: $0) })
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case credentialType
        case credentialValue
        case baseURL
        case anthropicModel
        case anthropicReasoningModel
        case anthropicDefaultHaikuModel
        case anthropicDefaultSonnetModel
        case anthropicDefaultOpusModel
        case anthropicSmallFastModel
        case source
        case usageQuery
        case createdAt
        case updatedAt
        case lastValidatedAt
        case lastValidationStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try container.decode(String.self, forKey: .name)
        let credentialType = try container.decode(ClaudeCredentialType.self, forKey: .credentialType)
        let credentialValue = try container.decode(String.self, forKey: .credentialValue)
        let baseURL = try container.decode(String.self, forKey: .baseURL)
        let source = try container.decode(ClaudeAccountSource.self, forKey: .source)
        let usageQuery = try container.decodeIfPresent(CodexHTTPUsageQuery.self, forKey: .usageQuery)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        let updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        let lastValidatedAt = try container.decodeIfPresent(Date.self, forKey: .lastValidatedAt)
        let lastValidationStatus = try container.decodeIfPresent(Bool.self, forKey: .lastValidationStatus)

        let model = try container.decodeIfPresent(String.self, forKey: .anthropicModel)
        let reasoning = try container.decodeIfPresent(String.self, forKey: .anthropicReasoningModel)
        let haiku = try container.decodeIfPresent(String.self, forKey: .anthropicDefaultHaikuModel)
        let sonnet = try container.decodeIfPresent(String.self, forKey: .anthropicDefaultSonnetModel)
        let opus = try container.decodeIfPresent(String.self, forKey: .anthropicDefaultOpusModel)
        let smallFast = try container.decodeIfPresent(String.self, forKey: .anthropicSmallFastModel)
        let resolvedModels = Self.resolveModels(
            model: model,
            reasoning: reasoning,
            haiku: haiku,
            sonnet: sonnet,
            opus: opus,
            smallFast: smallFast
        )

        self.init(
            id: id,
            name: name,
            credentialType: credentialType,
            credentialValue: credentialValue,
            baseURL: baseURL,
            anthropicModel: resolvedModels.model,
            anthropicReasoningModel: resolvedModels.reasoning,
            anthropicDefaultHaikuModel: resolvedModels.haiku,
            anthropicDefaultSonnetModel: resolvedModels.sonnet,
            anthropicDefaultOpusModel: resolvedModels.opus,
            source: source,
            usageQuery: usageQuery,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastValidatedAt: lastValidatedAt,
            lastValidationStatus: lastValidationStatus
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(credentialType, forKey: .credentialType)
        try container.encode(credentialValue, forKey: .credentialValue)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(anthropicModel, forKey: .anthropicModel)
        try container.encode(anthropicReasoningModel, forKey: .anthropicReasoningModel)
        try container.encode(anthropicDefaultHaikuModel, forKey: .anthropicDefaultHaikuModel)
        try container.encode(anthropicDefaultSonnetModel, forKey: .anthropicDefaultSonnetModel)
        try container.encode(anthropicDefaultOpusModel, forKey: .anthropicDefaultOpusModel)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(usageQuery, forKey: .usageQuery)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastValidatedAt, forKey: .lastValidatedAt)
        try container.encodeIfPresent(lastValidationStatus, forKey: .lastValidationStatus)
    }

    private static func resolveModels(
        model: String?,
        reasoning: String?,
        haiku: String?,
        sonnet: String?,
        opus: String?,
        smallFast: String?
    ) -> (model: String, reasoning: String, haiku: String, sonnet: String, opus: String) {
        let normalizedModel = normalizedModelValue(model)
        let normalizedReasoning = normalizedModelValue(reasoning)
        let normalizedSmallFast = normalizedModelValue(smallFast)
        let normalizedHaiku = normalizedModelValue(haiku) ?? normalizedSmallFast
        let normalizedSonnet = normalizedModelValue(sonnet)
        let normalizedOpus = normalizedModelValue(opus)
        return (
            model: normalizedModel ?? defaultAnthropicModel,
            reasoning: normalizedReasoning ?? defaultAnthropicReasoningModel,
            haiku: normalizedHaiku ?? defaultAnthropicDefaultHaikuModel,
            sonnet: normalizedSonnet ?? defaultAnthropicDefaultSonnetModel,
            opus: normalizedOpus ?? defaultAnthropicDefaultOpusModel
        )
    }

    private static func normalizedModelValue(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct ClaudeAccountValidationResult: Sendable, Equatable {
    public let isEffective: Bool
    public let statusCode: Int?
    public let message: String?
    public let validatedAt: Date

    public init(
        isEffective: Bool,
        statusCode: Int?,
        message: String?,
        validatedAt: Date = Date()
    ) {
        self.isEffective = isEffective
        self.statusCode = statusCode
        self.message = message
        self.validatedAt = validatedAt
    }
}

public struct ClaudeCCSwitchImportReport: Sendable, Equatable {
    public let totalCandidates: Int
    public let importedCount: Int
    public let replacedCount: Int
    public let skippedCount: Int

    public init(totalCandidates: Int, importedCount: Int, replacedCount: Int, skippedCount: Int) {
        self.totalCandidates = totalCandidates
        self.importedCount = importedCount
        self.replacedCount = replacedCount
        self.skippedCount = skippedCount
    }
}
