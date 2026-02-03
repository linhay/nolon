import Foundation
import CodexBarProviderCatalog

public struct ProviderUsageMonitorSettings: Sendable, Codable, Equatable {
    public var sourceMode: ProviderSourceMode
    public var includeCredits: Bool
    public var webTimeoutSeconds: Int

    public init(sourceMode: ProviderSourceMode = .auto, includeCredits: Bool = false, webTimeoutSeconds: Int = 30) {
        self.sourceMode = sourceMode
        self.includeCredits = includeCredits
        self.webTimeoutSeconds = webTimeoutSeconds
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

    public init(
        tokenAccountStore: ProviderTokenAccountStoring,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.tokenAccountStore = tokenAccountStore
        self.baseEnvironment = baseEnvironment
    }

    public func fetchOutcomes(provider: UsageProvider, settings: ProviderUsageMonitorSettings) async -> [ProviderAccountUsageOutcome] {
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
                        environment: self.baseEnvironment,
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
