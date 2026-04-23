import Foundation
import CodexBarProviderCatalog

public enum ProviderUsageRegistry {
    public static func descriptor(for provider: UsageProvider) -> any ProviderUsageDescribing {
        switch provider {
        case .codex:
            return CodexUsageDescriptor()
        case .copilot:
            return CopilotUsageDescriptor()
        case .gemini:
            return GeminiUsageDescriptor(provider: .gemini)
        case .antigravity:
            return GeminiUsageDescriptor(provider: .antigravity)
        case .claude:
            return ClaudeUsageDescriptor()
        case .cursor, .opencode, .factory, .zai, .minimax, .kimi, .kiro, .vertexai, .augment, .jetbrains, .kimik2, .amp, .synthetic:
            return UnsupportedUsageDescriptor(provider: provider)
        }
    }

    public static func fetchPlan(for provider: UsageProvider) -> ProviderFetchPlan {
        self.descriptor(for: provider).fetchPlan
    }

    public static func metadata(for provider: UsageProvider) -> ProviderMetadataPreset? {
        // The "CodexBarProviderCatalog" target already maintains the canonical list
        // of per-provider display metadata.
        return CodexBarProviderPresets.preset(for: provider).metadata
    }

    public static var metadataByProvider: [UsageProvider: ProviderMetadataPreset] {
        Dictionary(uniqueKeysWithValues: UsageProvider.allCases.map { provider in
            (provider, CodexBarProviderPresets.preset(for: provider).metadata)
        })
    }

    public static func fetchTokenTrendSnapshot(
        for provider: UsageProvider,
        trailingDays: Int?,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> ProviderTokenTrendSnapshot? {
        switch provider {
        case .codex:
            return try await CodexTokenTrendService().fetchGlobalSnapshot(
                trailingDays: trailingDays,
                environment: environment
            )
        case .claude:
            return try await ClaudeTokenTrendService().fetchActiveSnapshot(
                trailingDays: trailingDays
            )
        case .gemini, .antigravity:
            return try await GeminiTokenTrendService().fetchActiveSnapshot(
                provider: provider,
                trailingDays: trailingDays
            )
        default:
            return nil
        }
    }

    public static func fetchIntradaySnapshot(
        for provider: UsageProvider,
        dayKey: String,
        bucket: ProviderIntradayBucket,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> ProviderIntradayUsageSnapshot? {
        switch provider {
        case .codex:
            return try await CodexIntradayUsageService().fetchGlobalSnapshot(
                dayKey: dayKey,
                bucket: bucket,
                environment: environment
            )
        case .claude:
            return try await ClaudeIntradayUsageService().fetchActiveSnapshot(
                dayKey: dayKey,
                bucket: bucket
            )
        case .gemini, .antigravity:
            return try await GeminiIntradayUsageService().fetchActiveSnapshot(
                provider: provider,
                dayKey: dayKey,
                bucket: bucket
            )
        default:
            return nil
        }
    }

    public static func supportedIntradayBuckets(for provider: UsageProvider?) -> [ProviderIntradayBucket] {
        switch provider {
        case .claude, .gemini, .antigravity:
            return [.minute1, .minute5, .minute10, .minute15, .minute30, .hour1]
        case .codex:
            return [.minute1, .minute5, .minute10, .minute15, .minute30, .hour1]
        default:
            return [.minute1, .minute5, .minute10, .minute15, .minute30, .hour1]
        }
    }
}

private struct UnsupportedUsageDescriptor: ProviderUsageDescribing {
    let provider: UsageProvider
    let fetchPlan = ProviderFetchPlan(sourceModes: [.auto])

    func fetchOutcome(context _: ProviderFetchContext) async -> ProviderFetchOutcome {
        ProviderFetchOutcome(fetchKind: .localProbe, result: .failure(ProviderUsageError.unsupported(provider)))
    }
}
