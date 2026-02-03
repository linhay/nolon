import Foundation
import CodexBarProviderCatalog

public struct ProviderTokenAccount: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let label: String
    public let token: String
    public let addedAt: TimeInterval
    public let lastUsed: TimeInterval?

    public init(
        id: UUID,
        label: String,
        token: String,
        addedAt: TimeInterval,
        lastUsed: TimeInterval?
    ) {
        self.id = id
        self.label = label
        self.token = token
        self.addedAt = addedAt
        self.lastUsed = lastUsed
    }

    public var displayName: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("usage.account.token", value: "Token account", comment: "Token account label") : trimmed
    }
}

public struct ProviderTokenAccountData: Codable, Sendable, Equatable {
    public let version: Int
    public let accounts: [ProviderTokenAccount]
    public let activeIndex: Int

    public init(version: Int, accounts: [ProviderTokenAccount], activeIndex: Int) {
        self.version = version
        self.accounts = accounts
        self.activeIndex = activeIndex
    }

    public func clampedActiveIndex() -> Int {
        guard !accounts.isEmpty else { return 0 }
        return min(max(activeIndex, 0), accounts.count - 1)
    }
}

public protocol ProviderTokenAccountStoring: Sendable {
    func loadAccounts() throws -> [UsageProvider: ProviderTokenAccountData]
    func storeAccounts(_ accounts: [UsageProvider: ProviderTokenAccountData]) throws
}

public final class FileTokenAccountStore: ProviderTokenAccountStoring {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func loadAccounts() throws -> [UsageProvider: ProviderTokenAccountData] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty {
            return [:]
        }
        return try decoder.decode([UsageProvider: ProviderTokenAccountData].self, from: data)
    }

    public func storeAccounts(_ accounts: [UsageProvider: ProviderTokenAccountData]) throws {
        let folderURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(accounts)
        try data.write(to: fileURL, options: [.atomic])
    }
}

