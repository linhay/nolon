import Foundation
import CodexBarProviderCatalog
import CodexProvider

public struct ProviderUsageMonitorSettings: Sendable, Codable, Equatable {
    public var sourceMode: ProviderSourceMode
    public var includeCredits: Bool
    public var webTimeoutSeconds: Int
    public var autoRefreshIntervalMinutes: Int
    public var costWindowDays: Int?

    public init(
        sourceMode: ProviderSourceMode = .auto,
        includeCredits: Bool = false,
        webTimeoutSeconds: Int = 30,
        autoRefreshIntervalMinutes: Int = 0,
        costWindowDays: Int? = 30
    ) {
        self.sourceMode = sourceMode
        self.includeCredits = includeCredits
        self.webTimeoutSeconds = webTimeoutSeconds
        self.autoRefreshIntervalMinutes = autoRefreshIntervalMinutes
        self.costWindowDays = costWindowDays
    }

    public func effectiveCostWindowDays(selected: Int?) -> Int? {
        selected ?? costWindowDays
    }

    private enum CodingKeys: String, CodingKey {
        case sourceMode
        case includeCredits
        case webTimeoutSeconds
        case autoRefreshIntervalMinutes
        case costWindowDays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceMode = (try? container.decode(ProviderSourceMode.self, forKey: .sourceMode)) ?? .auto
        includeCredits = (try? container.decode(Bool.self, forKey: .includeCredits)) ?? false
        webTimeoutSeconds = (try? container.decode(Int.self, forKey: .webTimeoutSeconds)) ?? 30
        autoRefreshIntervalMinutes = (try? container.decode(Int.self, forKey: .autoRefreshIntervalMinutes)) ?? 0
        if container.contains(.costWindowDays) {
            // Keep explicit `null` as nil ("All"), only default when key is absent (legacy data).
            costWindowDays = try container.decodeIfPresent(Int.self, forKey: .costWindowDays)
        } else {
            costWindowDays = 30
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceMode, forKey: .sourceMode)
        try container.encode(includeCredits, forKey: .includeCredits)
        try container.encode(webTimeoutSeconds, forKey: .webTimeoutSeconds)
        try container.encode(autoRefreshIntervalMinutes, forKey: .autoRefreshIntervalMinutes)
        if let costWindowDays {
            try container.encode(costWindowDays, forKey: .costWindowDays)
        } else {
            // Persist explicit null so decode can distinguish it from missing key.
            try container.encodeNil(forKey: .costWindowDays)
        }
    }
}

public struct ProviderAccountUsageOutcome: Identifiable, Sendable {
    public enum AccountKind: Sendable {
        case `default`
        case tokenAccount(ProviderTokenAccount)
    }

    public let provider: UsageProvider
    public let account: AccountKind
    public let outcome: ProviderFetchOutcome

    public init(provider: UsageProvider, account: AccountKind, outcome: ProviderFetchOutcome) {
        self.provider = provider
        self.account = account
        self.outcome = outcome
    }

    public var id: String {
        switch account {
        case .default:
            return "\(provider.rawValue).default"
        case let .tokenAccount(account):
            return "\(provider.rawValue).\(account.id.uuidString)"
        }
    }
}

public actor ProviderUsageMonitorService {
    private let tokenAccountStore: ProviderTokenAccountStoring
    private let baseEnvironment: [String: String]
    private let codexManagedEnvironmentLoader: @Sendable () async throws -> [String: String]
    private let codexCLIPathLoader: @Sendable () async -> String?

    public init(
        tokenAccountStore: ProviderTokenAccountStoring,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.tokenAccountStore = tokenAccountStore
        self.baseEnvironment = baseEnvironment
        self.codexManagedEnvironmentLoader = {
            try await CodexBinaryManager.shared.launchEnvironmentVariables()
        }
        self.codexCLIPathLoader = {
            await CodexBinaryManager.shared.activeCLIPathIfAvailable()
        }
    }

    init(
        tokenAccountStore: ProviderTokenAccountStoring,
        baseEnvironment: [String: String],
        codexManagedEnvironmentLoader: @escaping @Sendable () async throws -> [String: String],
        codexCLIPathLoader: @escaping @Sendable () async -> String?
    ) {
        self.tokenAccountStore = tokenAccountStore
        self.baseEnvironment = baseEnvironment
        self.codexManagedEnvironmentLoader = codexManagedEnvironmentLoader
        self.codexCLIPathLoader = codexCLIPathLoader
    }

    func resolveEnvironmentForFetch(provider: UsageProvider) async -> [String: String] {
        var environment = baseEnvironment
        guard provider == .codex else { return environment }

        if let managedEnvironment = try? await codexManagedEnvironmentLoader() {
            environment.merge(managedEnvironment) { _, new in new }
        }
        if let codexCLIPath = await codexCLIPathLoader() {
            environment["CODEX_CLI_PATH"] = codexCLIPath
        }
        return environment
    }

    public func fetchOutcomes(
        provider: UsageProvider,
        settings: ProviderUsageMonitorSettings,
        costWindowDays: Int? = 30
    ) async -> [ProviderAccountUsageOutcome] {
        let resolvedEnvironment = await resolveEnvironmentForFetch(provider: provider)
        let tokenAccounts: [ProviderTokenAccount] = (try? tokenAccountStore.loadAccounts()[provider]?.accounts) ?? []
        var accountKinds: [ProviderAccountUsageOutcome.AccountKind] = [.default]
        accountKinds.append(contentsOf: tokenAccounts.map { .tokenAccount($0) })

        return await withTaskGroup(of: ProviderAccountUsageOutcome.self) { group in
            for account in accountKinds {
                group.addTask {
                    let token: String?
                    switch account {
                    case .default:
                        token = nil
                    case let .tokenAccount(account):
                        token = account.token
                    }

                    let context = ProviderFetchContext(
                        provider: provider,
                        sourceMode: settings.sourceMode,
                        includeCredits: settings.includeCredits,
                        timeout: TimeInterval(settings.webTimeoutSeconds),
                        costWindowDays: costWindowDays,
                        environment: resolvedEnvironment,
                        token: token
                    )

                    let descriptor = ProviderUsageRegistry.descriptor(for: provider)
                    let outcome = await descriptor.fetchOutcome(context: context)
                    return ProviderAccountUsageOutcome(provider: provider, account: account, outcome: outcome)
                }
            }

            var results: [ProviderAccountUsageOutcome] = []
            for await item in group {
                results.append(item)
            }

            return results.sorted { left, right in
                switch (left.account, right.account) {
                case (.default, .tokenAccount):
                    return true
                case (.tokenAccount, .default):
                    return false
                case let (.tokenAccount(a), .tokenAccount(b)):
                    return a.addedAt < b.addedAt
                default:
                    return false
                }
            }
        }
    }
}
