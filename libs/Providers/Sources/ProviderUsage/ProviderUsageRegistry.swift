import Foundation
import CodexBarProviderCatalog

public enum ProviderUsageRegistry {
    public static func descriptor(for provider: UsageProvider) -> any ProviderUsageDescribing {
        switch provider {
        case .codex:
            return CodexUsageDescriptor()
        case .copilot:
            return CopilotUsageDescriptor()
        case .claude, .cursor, .opencode, .factory, .gemini, .antigravity, .zai, .minimax, .kimi, .kiro, .vertexai, .augment, .jetbrains, .kimik2, .amp, .synthetic:
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
}

private struct UnsupportedUsageDescriptor: ProviderUsageDescribing {
    let provider: UsageProvider
    let fetchPlan = ProviderFetchPlan(sourceModes: [.auto])

    func fetchOutcome(context _: ProviderFetchContext) async -> ProviderFetchOutcome {
        ProviderFetchOutcome(fetchKind: .localProbe, result: .failure(ProviderUsageError.unsupported(provider)))
    }
}

