import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import UniformTypeIdentifiers

typealias UsageEngineCodexActivateAction = @MainActor @Sendable (CodexAuthAccount, Provider) async throws -> Void
typealias UsageEngineCodexDeleteAction = @MainActor @Sendable (UUID) async throws -> Void
typealias UsageEngineCodexRefreshAllAction = @MainActor @Sendable ([CodexAuthAccount]) async -> Void
typealias UsageEngineCodexPreflightAction = @MainActor @Sendable (Provider, Bool, String) async throws -> CodexAuthAccount?
typealias UsageEngineCodexOutcomeFetchAction = @Sendable (CodexAuthAccount, UsageMonitorProviderSettings, URL) async -> ProviderAccountUsageOutcome
typealias UsageEngineCodexUsageQueryTestAction = @MainActor @Sendable (CodexHTTPUsageQueryResolvedConfiguration, Bool) async throws -> ProviderFetchResult
typealias UsageEngineCodexConfiguredAccountValidateAction = @Sendable (CodexAuthAccount) async throws -> String
typealias UsageEngineCodexImportConnectionTestAction = @Sendable (CodexAuthManager.CodexImportValidationResult, UsageMonitorProviderSettings) async -> ProviderAccountUsageOutcome
typealias UsageEngineCodexImportOpenPanelAction = @MainActor @Sendable () -> [URL]
typealias UsageEngineCodexExportSavePanelAction = @MainActor @Sendable (UTType, String) -> URL?
typealias UsageEngineCodexImportExportArchiveAction = @MainActor @Sendable ([CodexAuthManager.CodexImportValidationResult], URL) async throws -> Int
typealias UsageEngineClaudeTokenTrendFetchAction = @Sendable (Int?) async throws -> ProviderTokenTrendSnapshot?
typealias UsageEngineGeminiTokenTrendFetchAction = @Sendable (UsageProvider, Int?) async throws -> ProviderTokenTrendSnapshot?
typealias UsageEngineProviderIntradayFetchAction = @Sendable (UsageProvider, String, ProviderIntradayBucket) async throws -> ProviderIntradayUsageSnapshot?
typealias UsageEngineAsyncVoidAction = @MainActor @Sendable () async -> Void

extension ProviderUsageEngine {
    struct ActionDependencies {
        let codexActivate: CodexActivateAction
        let postActivationLoad: AsyncVoidAction?
        let codexDelete: CodexDeleteAction?
        let postDeleteLoad: AsyncVoidAction?
        let codexRefreshAll: CodexRefreshAllAction?
        let codexPreflight: CodexPreflightAction?
        let codexOutcomeFetch: CodexOutcomeFetchAction
        let codexUsageQueryTest: CodexUsageQueryTestAction
        let codexConfiguredAccountValidate: CodexConfiguredAccountValidateAction
        let codexImportConnectionTest: CodexImportConnectionTestAction
        let codexImportOpenPanel: CodexImportOpenPanelAction
        let codexExportSavePanel: CodexExportSavePanelAction
        let codexImportExportArchive: CodexImportExportArchiveAction
        let claudeTokenTrendFetch: ClaudeTokenTrendFetchAction
        let geminiTokenTrendFetch: GeminiTokenTrendFetchAction
        let providerIntradayFetch: ProviderIntradayFetchAction
    }

    typealias CodexActivateAction = UsageEngineCodexActivateAction
    typealias CodexDeleteAction = UsageEngineCodexDeleteAction
    typealias CodexRefreshAllAction = UsageEngineCodexRefreshAllAction
    typealias CodexPreflightAction = UsageEngineCodexPreflightAction
    typealias CodexOutcomeFetchAction = UsageEngineCodexOutcomeFetchAction
    typealias CodexUsageQueryTestAction = UsageEngineCodexUsageQueryTestAction
    typealias CodexConfiguredAccountValidateAction = UsageEngineCodexConfiguredAccountValidateAction
    typealias CodexImportConnectionTestAction = UsageEngineCodexImportConnectionTestAction
    typealias CodexImportOpenPanelAction = UsageEngineCodexImportOpenPanelAction
    typealias CodexExportSavePanelAction = UsageEngineCodexExportSavePanelAction
    typealias CodexImportExportArchiveAction = UsageEngineCodexImportExportArchiveAction
    typealias ClaudeTokenTrendFetchAction = UsageEngineClaudeTokenTrendFetchAction
    typealias GeminiTokenTrendFetchAction = UsageEngineGeminiTokenTrendFetchAction
    typealias ProviderIntradayFetchAction = UsageEngineProviderIntradayFetchAction
    typealias AsyncVoidAction = UsageEngineAsyncVoidAction
}
