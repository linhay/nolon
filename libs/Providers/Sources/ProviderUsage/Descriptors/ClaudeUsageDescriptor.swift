import Foundation
import CodexBarProviderCatalog

public struct ClaudeUsageDescriptor: ProviderUsageDescribing {
    public let provider: UsageProvider = .claude
    public let fetchPlan = ProviderFetchPlan(sourceModes: [.auto, .web])

    private let loadActiveAccount: @Sendable () async throws -> ClaudeAccount?
    private let executeHTTPUsageQuery: @Sendable (_ resolved: CodexHTTPUsageQueryResolvedConfiguration, _ includeCredits: Bool) async throws -> ProviderFetchResult

    public init() {
        let manager = ClaudeAccountManager()
        self.loadActiveAccount = {
            let activeID = try await manager.activeAccountID()
            guard let activeID else { return nil }
            let accounts = try await manager.loadAccounts()
            return accounts.first(where: { $0.id == activeID })
        }
        self.executeHTTPUsageQuery = { resolved, includeCredits in
            try await CodexHTTPUsageQueryExecutor().execute(resolved, includeCredits: includeCredits)
        }
    }

    init(
        loadActiveAccount: @escaping @Sendable () async throws -> ClaudeAccount?,
        executeHTTPUsageQuery: @escaping @Sendable (_ resolved: CodexHTTPUsageQueryResolvedConfiguration, _ includeCredits: Bool) async throws -> ProviderFetchResult
    ) {
        self.loadActiveAccount = loadActiveAccount
        self.executeHTTPUsageQuery = executeHTTPUsageQuery
    }

    public func fetchOutcome(context: ProviderFetchContext) async -> ProviderFetchOutcome {
        do {
            guard let account = try await loadActiveAccount() else {
                return ProviderFetchOutcome(fetchKind: .web, result: .failure(ProviderUsageError.missingAccount(.claude)))
            }
            guard let usageQuery = account.usageQuery else {
                return ProviderFetchOutcome(fetchKind: .web, result: .failure(ProviderUsageError.unsupported(.claude)))
            }

            let defaults = CodexHTTPUsageQueryCredentials(
                baseURL: account.baseURL,
                apiKey: account.credentialValue,
                accessToken: nil,
                userID: nil
            )
            let resolved = CodexHTTPUsageQueryResolvedConfiguration(
                query: usageQuery,
                defaultCredentials: defaults,
                cardKind: nil,
                source: .explicit
            )
            let result = try await executeHTTPUsageQuery(resolved, context.includeCredits)
            return ProviderFetchOutcome(fetchKind: .web, result: .success(result))
        } catch {
            return ProviderFetchOutcome(fetchKind: .web, result: .failure(error))
        }
    }
}
