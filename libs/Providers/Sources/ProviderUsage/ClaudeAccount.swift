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
    public let id: UUID
    public var name: String
    public var credentialType: ClaudeCredentialType
    public var credentialValue: String
    public var baseURL: String
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
        hasher.combine(source)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
        hasher.combine(lastValidatedAt)
        hasher.combine(lastValidationStatus)
        hasher.combine(usageQuery.map { String(describing: $0) })
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
