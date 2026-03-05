import Foundation
import CodexBarProviderCatalog

public struct GeminiUsageDescriptor: ProviderUsageDescribing {
    public let provider: UsageProvider
    public let fetchPlan = ProviderFetchPlan(sourceModes: [.auto, .cli])

    private let now: @Sendable () -> Date
    private let loadActiveAccount: @Sendable (UsageProvider) async throws -> GeminiAuthAccount?

    public init(provider: UsageProvider) {
        self.provider = provider
        self.now = Date.init
        let store = GeminiAuthStore.shared
        self.loadActiveAccount = { requested in
            try await store.activeAccount(provider: requested)
        }
    }

    init(
        provider: UsageProvider,
        now: @escaping @Sendable () -> Date,
        loadActiveAccount: @escaping @Sendable (UsageProvider) async throws -> GeminiAuthAccount?
    ) {
        self.provider = provider
        self.now = now
        self.loadActiveAccount = loadActiveAccount
    }

    public func fetchOutcome(context: ProviderFetchContext) async -> ProviderFetchOutcome {
        do {
            guard let account = try await loadActiveAccount(context.provider) else {
                return ProviderFetchOutcome(
                    fetchKind: .cli,
                    result: .failure(ProviderUsageError.missingAccount(context.provider))
                )
            }

            let usage = UsageSnapshot(
                identity: identity(for: account),
                primary: nil,
                secondary: nil,
                tertiary: nil,
                updatedAt: account.lastUsedAt ?? account.lastLoginAt ?? now()
            )
            let fetchKind = fetchKind(for: account.method)
            let result = ProviderFetchResult(
                usage: usage,
                credits: nil,
                cost: nil,
                sourceLabel: sourceLabel(for: account.method),
                fetchKind: fetchKind,
                strategyKind: .direct
            )
            return ProviderFetchOutcome(fetchKind: .cli, result: .success(result))
        } catch {
            return ProviderFetchOutcome(fetchKind: .cli, result: .failure(error))
        }
    }

    private func identity(for account: GeminiAuthAccount) -> UsageIdentity {
        let organization: String? = {
            let project = account.project?.trimmingCharacters(in: .whitespacesAndNewlines)
            let location = account.location?.trimmingCharacters(in: .whitespacesAndNewlines)
            switch (project?.isEmpty == false ? project : nil, location?.isEmpty == false ? location : nil) {
            case let (project?, location?):
                return "\(project)@\(location)"
            case let (project?, nil):
                return project
            case let (nil, location?):
                return location
            case (nil, nil):
                return nil
            }
        }()

        return UsageIdentity(
            accountEmail: account.email,
            accountOrganization: organization,
            loginMethod: loginMethodLabel(for: account.method),
            plan: account.method.rawValue
        )
    }

    private func loginMethodLabel(for method: GeminiAuthMethod) -> String {
        switch method {
        case .oauthPersonal:
            return "oauth"
        case .geminiAPIKey:
            return "api_key"
        case .vertexAI:
            return "vertex"
        }
    }

    private func fetchKind(for method: GeminiAuthMethod) -> ProviderFetchKind {
        switch method {
        case .oauthPersonal:
            return .oauth
        case .geminiAPIKey:
            return .apiToken
        case .vertexAI:
            return .cli
        }
    }

    private func sourceLabel(for method: GeminiAuthMethod) -> String {
        switch method {
        case .oauthPersonal:
            return NSLocalizedString("usage.source.oauth", value: "OAuth", comment: "OAuth")
        case .geminiAPIKey:
            return NSLocalizedString("usage.source.api_token", value: "API token", comment: "API token")
        case .vertexAI:
            return NSLocalizedString("usage.source.cli", value: "CLI", comment: "CLI")
        }
    }
}
