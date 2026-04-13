import Foundation
import CodexBarProviderCatalog

public struct GeminiUsageDescriptor: ProviderUsageDescribing {
    public let provider: UsageProvider
    public let fetchPlan = ProviderFetchPlan(sourceModes: [.auto, .cli])

    private let now: @Sendable () -> Date
    private let loadActiveAccount: @Sendable (UsageProvider) async throws -> GeminiAuthAccount?
    private let loadRuntimeHomeURL: @Sendable (UsageProvider, UUID) async throws -> URL
    private let fetchQuotaSnapshot: @Sendable (URL, GeminiAuthMethod, [String: String]) async throws -> GeminiQuotaSnapshot?

    public init(provider: UsageProvider) {
        self.provider = provider
        self.now = Date.init
        let store = GeminiAuthStore.shared
        let fetcher = GeminiQuotaFetcher()
        self.loadActiveAccount = { requested in
            try await store.activeAccount(provider: requested)
        }
        self.loadRuntimeHomeURL = { requested, accountID in
            try await store.runtimeHomeURL(provider: requested, accountID: accountID)
        }
        self.fetchQuotaSnapshot = { runtimeHomeURL, _, environment in
            guard let account = try await store.activeAccount(provider: provider) else {
                return nil
            }
            return try await fetcher.fetch(
                account: account,
                runtimeHomeURL: runtimeHomeURL,
                environment: environment
            )
        }
    }

    init(
        provider: UsageProvider,
        now: @escaping @Sendable () -> Date,
        loadActiveAccount: @escaping @Sendable (UsageProvider) async throws -> GeminiAuthAccount?,
        loadRuntimeHomeURL: @escaping @Sendable (UsageProvider, UUID) async throws -> URL = { _, _ in
            URL(fileURLWithPath: "/tmp", isDirectory: true)
        },
        fetchQuotaSnapshot: @escaping @Sendable (URL, GeminiAuthMethod, [String: String]) async throws -> GeminiQuotaSnapshot? = { _, _, _ in
            nil
        }
    ) {
        self.provider = provider
        self.now = now
        self.loadActiveAccount = loadActiveAccount
        self.loadRuntimeHomeURL = loadRuntimeHomeURL
        self.fetchQuotaSnapshot = fetchQuotaSnapshot
    }

    public func fetchOutcome(context: ProviderFetchContext) async -> ProviderFetchOutcome {
        do {
            guard let account = try await loadActiveAccount(context.provider) else {
                return ProviderFetchOutcome(
                    fetchKind: .cli,
                    result: .failure(ProviderUsageError.missingAccount(context.provider))
                )
            }

            let baseIdentity = identity(for: account)
            let baseUpdatedAt = account.lastUsedAt ?? account.lastLoginAt ?? now()
            var usage = UsageSnapshot(
                identity: baseIdentity,
                windows: [],
                primary: nil,
                secondary: nil,
                tertiary: nil,
                updatedAt: baseUpdatedAt
            )
            let fetchKind = fetchKind(for: account.method)
            var strategyKind: ProviderFetchStrategyKind = .direct

            if account.method == .oauthPersonal {
                do {
                    let runtimeHomeURL = try await loadRuntimeHomeURL(context.provider, account.id)
                    if let quota = try await fetchQuotaSnapshot(runtimeHomeURL, account.method, context.environment) {
                        let windows = GeminiQuotaModelSupport
                            .sortAndDeduplicate(quota.buckets)
                            .map(Self.usageWindow)
                        usage = UsageSnapshot(
                            identity: baseIdentity,
                            windows: windows,
                            primary: windows.indices.contains(0) ? windows[0].window : nil,
                            secondary: windows.indices.contains(1) ? windows[1].window : nil,
                            tertiary: windows.indices.contains(2) ? windows[2].window : nil,
                            updatedAt: quota.fetchedAt
                        )
                    }
                } catch {
                    if context.sourceMode == .cli {
                        return ProviderFetchOutcome(fetchKind: fetchKind, result: .failure(error))
                    }
                    strategyKind = .fallback
                }
            }

            let result = ProviderFetchResult(
                usage: usage,
                credits: nil,
                cost: nil,
                sourceLabel: sourceLabel(for: account.method),
                fetchKind: fetchKind,
                strategyKind: strategyKind
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

    private static func rateWindow(from bucket: GeminiQuotaBucket) -> RateWindow {
        let remaining = min(max(bucket.remainingFraction, 0), 1)
        return RateWindow(
            usedPercent: (1 - remaining) * 100,
            resetDescription: nil,
            resetsAt: bucket.resetTime,
            windowMinutes: nil
        )
    }

    private static func usageWindow(from bucket: GeminiQuotaBucket) -> UsageWindow {
        UsageWindow(
            id: bucket.modelID,
            title: GeminiQuotaModelSupport.displayTitle(for: bucket.modelID),
            window: rateWindow(from: bucket)
        )
    }
}
