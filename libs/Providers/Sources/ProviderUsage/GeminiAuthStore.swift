import Foundation
import CodexBarProviderCatalog

public enum GeminiAuthStoreError: LocalizedError, Sendable, Equatable {
    case unsupportedProvider(UsageProvider)
    case accountNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedProvider(provider):
            return "Gemini auth store does not support provider: \(provider.rawValue)"
        case let .accountNotFound(id):
            return "Gemini account not found: \(id.uuidString.lowercased())"
        }
    }
}

private struct GeminiAuthProviderState: Codable, Sendable, Equatable {
    let version: Int
    let activeAccountID: UUID?
    let accounts: [GeminiAuthAccount]

    init(version: Int = 1, activeAccountID: UUID? = nil, accounts: [GeminiAuthAccount] = []) {
        self.version = max(version, 1)
        self.activeAccountID = activeAccountID
        self.accounts = accounts
    }
}

public struct GeminiCLIGlobalSessionImportCandidate: Sendable, Equatable {
    public let provider: UsageProvider
    public let geminiDirectoryPath: String
    public let email: String?

    public init(provider: UsageProvider, geminiDirectoryPath: String, email: String?) {
        self.provider = provider
        self.geminiDirectoryPath = geminiDirectoryPath
        self.email = email
    }
}

public actor GeminiAuthStore {
    public static let shared = GeminiAuthStore()

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let now: @Sendable () -> Date

    public init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            self.rootDirectory = appSupport
                .appendingPathComponent("Nolon", isDirectory: true)
                .appendingPathComponent("gemini-auth", isDirectory: true)
        }
        self.fileManager = fileManager
        self.now = now

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func listAccounts(provider: UsageProvider) throws -> [GeminiAuthAccount] {
        try validateProvider(provider)
        return try loadState(provider: provider).accounts
    }

    public func activeAccount(provider: UsageProvider) throws -> GeminiAuthAccount? {
        try validateProvider(provider)
        let state = try loadState(provider: provider)
        guard let active = state.activeAccountID else { return nil }
        return state.accounts.first(where: { $0.id == active })
    }

    public func upsertAccount(
        provider: UsageProvider,
        accountID: UUID? = nil,
        name: String,
        method: GeminiAuthMethod,
        email: String? = nil,
        project: String? = nil,
        location: String? = nil,
        markActive: Bool = true,
        updateLastLoginAt: Bool = false
    ) throws -> GeminiAuthAccount {
        try validateProvider(provider)
        var state = try loadState(provider: provider)
        let id = accountID ?? UUID()
        let normalizedName = Self.normalized(name) ?? "account-\(id.uuidString.prefix(8).lowercased())"
        let timestamp = now()
        let runtimePath = runtimeHomeRelativePath(provider: provider, accountID: id)

        let newAccount = GeminiAuthAccount(
            id: id,
            providerID: provider,
            name: normalizedName,
            method: method,
            createdAt: state.accounts.first(where: { $0.id == id })?.createdAt ?? timestamp,
            lastUsedAt: timestamp,
            lastLoginAt: updateLastLoginAt ? timestamp : state.accounts.first(where: { $0.id == id })?.lastLoginAt,
            email: Self.normalized(email),
            project: Self.normalized(project),
            location: Self.normalized(location),
            runtimeHomeRelativePath: runtimePath
        )

        var nextAccounts = state.accounts.filter { $0.id != id }
        nextAccounts.append(newAccount)
        nextAccounts.sort { $0.createdAt < $1.createdAt }
        state = GeminiAuthProviderState(
            version: max(state.version, 1),
            activeAccountID: markActive ? id : state.activeAccountID,
            accounts: nextAccounts
        )
        try storeState(provider: provider, state: state)
        try ensureRuntimeHomeExists(provider: provider, accountID: id)
        return newAccount
    }

    public func activate(provider: UsageProvider, accountID: UUID) throws -> GeminiAuthAccount {
        try validateProvider(provider)
        var state = try loadState(provider: provider)
        guard let account = state.accounts.first(where: { $0.id == accountID }) else {
            throw GeminiAuthStoreError.accountNotFound(accountID)
        }
        state = GeminiAuthProviderState(
            version: max(state.version, 1),
            activeAccountID: accountID,
            accounts: state.accounts
        )
        try storeState(provider: provider, state: state)
        return account
    }

    public func delete(provider: UsageProvider, accountID: UUID) throws {
        try validateProvider(provider)
        let state = try loadState(provider: provider)
        guard state.accounts.contains(where: { $0.id == accountID }) else {
            throw GeminiAuthStoreError.accountNotFound(accountID)
        }
        let filtered = state.accounts.filter { $0.id != accountID }
        let nextActive: UUID? = {
            guard !filtered.isEmpty else { return nil }
            if state.activeAccountID == accountID {
                return filtered.last?.id
            }
            return state.activeAccountID
        }()
        let nextState = GeminiAuthProviderState(
            version: max(state.version, 1),
            activeAccountID: nextActive,
            accounts: filtered
        )
        try storeState(provider: provider, state: nextState)
    }

    public func runtimeHomeURL(provider: UsageProvider, accountID: UUID) throws -> URL {
        try validateProvider(provider)
        return providerRoot(provider).appendingPathComponent(runtimeHomeRelativePath(provider: provider, accountID: accountID), isDirectory: true)
    }

    public func ensureRuntimeHomeExists(provider: UsageProvider, accountID: UUID) throws {
        let runtimeHome = try runtimeHomeURL(provider: provider, accountID: accountID)
        try fileManager.createDirectory(at: runtimeHome, withIntermediateDirectories: true)
    }

    /// Detect whether a global Gemini CLI session can be imported into Nolon-managed Gemini auth store.
    /// - Note: Intentionally limited to `.gemini` to keep antigravity isolated.
    public func globalSessionImportCandidate(
        provider: UsageProvider,
        environment: [String: String]
    ) throws -> GeminiCLIGlobalSessionImportCandidate? {
        try validateProvider(provider)
        guard provider == .gemini else { return nil }

        if try activeAccount(provider: provider) != nil { return nil }
        if !(try listAccounts(provider: provider)).isEmpty { return nil }

        let globalGeminiDirectory = resolveGlobalGeminiDirectory(environment: environment).standardizedFileURL
        guard hasCredentialArtifacts(in: globalGeminiDirectory) else {
            return nil
        }

        let email = activeGoogleEmail(in: globalGeminiDirectory)
        return GeminiCLIGlobalSessionImportCandidate(
            provider: provider,
            geminiDirectoryPath: globalGeminiDirectory.path,
            email: email
        )
    }

    /// Import an existing global Gemini CLI session into Nolon-managed Gemini auth store.
    /// Must be called explicitly by UI after user confirmation.
    @discardableResult
    public func importFromCLIGlobalSession(
        provider: UsageProvider,
        environment: [String: String]
    ) throws -> GeminiAuthAccount? {
        guard let candidate = try globalSessionImportCandidate(provider: provider, environment: environment) else {
            return nil
        }

        let sourceGeminiDirectory = URL(fileURLWithPath: candidate.geminiDirectoryPath, isDirectory: true)
        let email = candidate.email
        let accountName = email ?? "Gemini OAuth (Imported)"
        let imported = try upsertAccount(
            provider: provider,
            name: accountName,
            method: .oauthPersonal,
            email: email,
            markActive: true,
            updateLastLoginAt: false
        )

        let runtimeHome = try runtimeHomeURL(provider: provider, accountID: imported.id)
        try mirrorCredentialArtifactsIfPresent(from: sourceGeminiDirectory, to: runtimeHome)
        return imported
    }

    private func validateProvider(_ provider: UsageProvider) throws {
        guard provider == .gemini || provider == .antigravity else {
            throw GeminiAuthStoreError.unsupportedProvider(provider)
        }
    }

    private func providerRoot(_ provider: UsageProvider) -> URL {
        rootDirectory.appendingPathComponent(provider.rawValue, isDirectory: true)
    }

    private func stateFileURL(provider: UsageProvider) -> URL {
        providerRoot(provider).appendingPathComponent("accounts.json")
    }

    private func runtimeHomeRelativePath(provider: UsageProvider, accountID: UUID) -> String {
        "accounts/\(accountID.uuidString.lowercased())/home"
    }

    private func resolveGlobalGeminiDirectory(environment: [String: String]) -> URL {
        if let cliHome = Self.normalized(environment["GEMINI_CLI_HOME"]) {
            return URL(fileURLWithPath: cliHome, isDirectory: true)
                .appendingPathComponent(".gemini", isDirectory: true)
        }
        if let home = Self.normalized(environment["HOME"]) {
            return URL(fileURLWithPath: home, isDirectory: true)
                .appendingPathComponent(".gemini", isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini", isDirectory: true)
    }

    private func hasCredentialArtifacts(in geminiDirectory: URL) -> Bool {
        Self.credentialArtifactNames.contains { fileName in
            let fileURL = geminiDirectory.appendingPathComponent(fileName, isDirectory: false)
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                return false
            }
            return (values.fileSize ?? 0) > 0
        }
    }

    private func activeGoogleEmail(in geminiDirectory: URL) -> String? {
        let accountsURL = geminiDirectory.appendingPathComponent("google_accounts.json", isDirectory: false)
        guard let data = try? Data(contentsOf: accountsURL),
              !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let active = json["active"] as? String else {
            return nil
        }
        return Self.normalized(active)
    }

    private func mirrorCredentialArtifactsIfPresent(from sourceGeminiDirectory: URL, to runtimeHome: URL) throws {
        let targetGeminiDirectory = runtimeHome.appendingPathComponent(".gemini", isDirectory: true)
        try fileManager.createDirectory(at: targetGeminiDirectory, withIntermediateDirectories: true)

        for fileName in Self.mirrorArtifactNames {
            let source = sourceGeminiDirectory.appendingPathComponent(fileName, isDirectory: false)
            guard fileManager.fileExists(atPath: source.path),
                  let data = try? Data(contentsOf: source),
                  !data.isEmpty else {
                continue
            }
            let target = targetGeminiDirectory.appendingPathComponent(fileName, isDirectory: false)
            try data.write(to: target, options: .atomic)
        }
    }

    private func loadState(provider: UsageProvider) throws -> GeminiAuthProviderState {
        let fileURL = stateFileURL(provider: provider)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return GeminiAuthProviderState()
        }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty {
            return GeminiAuthProviderState()
        }
        return try decoder.decode(GeminiAuthProviderState.self, from: data)
    }

    private func storeState(provider: UsageProvider, state: GeminiAuthProviderState) throws {
        let fileURL = stateFileURL(provider: provider)
        try fileManager.createDirectory(at: providerRoot(provider), withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let credentialArtifactNames: [String] = [
        "oauth_creds.json",
        "mcp-oauth-tokens-v2.json",
        "mcp-oauth-tokens.json"
    ]

    private static let mirrorArtifactNames: [String] = [
        "oauth_creds.json",
        "mcp-oauth-tokens-v2.json",
        "mcp-oauth-tokens.json",
        "google_accounts.json",
        "settings.json"
    ]
}
