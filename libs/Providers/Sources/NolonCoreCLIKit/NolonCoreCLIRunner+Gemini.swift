import Foundation
import ProviderCatalog
import NolonResourceKit
import ProviderUsage
import CodexBarProviderCatalog
import SKProcessRunner
import STFilePath

extension NolonCoreCLIRunner {
    func resolveGeminiAuthProvider(_ providerID: String) throws -> UsageProvider {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Missing required option: --provider (gemini|antigravity).")
        }
        guard let provider = UsageProvider(rawValue: normalized),
              provider == .gemini || provider == .antigravity
        else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(providerID). Expected gemini or antigravity.")
        }
        return provider
    }

    func geminiAuthStore() -> GeminiAuthStore {
        GeminiAuthStore.shared
    }

    func parseGeminiAuthMethod(_ raw: String) throws -> GeminiAuthMethod {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let method = GeminiAuthMethod(rawValue: normalized) else {
            throw NolonCoreCLIError.invalidArguments(
                "Unsupported --method: \(raw). Expected oauth-personal, gemini-api-key, or vertex-ai."
            )
        }
        return method
    }

    func activeGeminiAccountID(provider: UsageProvider) async throws -> UUID? {
        try await geminiAuthStore().activeAccount(provider: provider)?.id
    }

    func loadGeminiAccountListing(provider: UsageProvider) async throws -> (activeAccountID: UUID?, accounts: [GeminiAuthAccountView]) {
        let store = geminiAuthStore()
        let activeID = try await store.activeAccount(provider: provider)?.id
        let accounts = try await store.listAccounts(provider: provider).map { account in
            GeminiAuthAccountView(
                id: account.id.uuidString.lowercased(),
                label: account.name,
                method: account.method.rawValue,
                isActive: account.id == activeID,
                createdAt: account.createdAt,
                lastUsedAt: account.lastUsedAt
            )
        }
        return (activeID, accounts)
    }

    func geminiAuthLogin(
        provider: UsageProvider,
        methodRaw: String,
        timeoutSeconds: Int,
        name: String?,
        email: String?,
        apiKey: String?,
        googleAPIKey: String?,
        project: String?,
        location: String?,
        useADC: Bool
    ) async throws -> GeminiAuthMutationPayload {
        let method = try parseGeminiAuthMethod(methodRaw)
        let displayName: String = {
            if let name = normalizedNonEmpty(name) { return name }
            if let email = normalizedNonEmpty(email) { return email }
            switch method {
            case .oauthPersonal:
                return "gemini-oauth"
            case .geminiAPIKey:
                return "gemini-api-key"
            case .vertexAI:
                return "gemini-vertex"
            }
        }()

        let store = geminiAuthStore()
        let accountID = UUID()
        var loginURL: String?

        switch method {
        case .oauthPersonal:
            let runtimeHome = try await store.runtimeHomeURL(provider: provider, accountID: accountID)
            let runner = GeminiLoginRunner()
            let result = try await runner.loginWithOAuthAndAwait(
                provider: provider,
                accountID: accountID,
                runtimeHomeURL: runtimeHome,
                timeoutSeconds: TimeInterval(max(timeoutSeconds, 30))
            )
            loginURL = result.loginURL
            _ = try await store.upsertAccount(
                provider: provider,
                accountID: accountID,
                name: displayName,
                method: .oauthPersonal,
                email: normalizedNonEmpty(email),
                markActive: true,
                updateLastLoginAt: true
            )
        case .geminiAPIKey:
            let effectiveKey = normalizedNonEmpty(apiKey) ?? normalizedNonEmpty(ProcessInfo.processInfo.environment["GEMINI_API_KEY"])
            guard effectiveKey != nil else {
                throw NolonCoreCLIError.invalidArguments("Missing Gemini API key. Pass --api-key or set GEMINI_API_KEY.")
            }
            _ = try await store.upsertAccount(
                provider: provider,
                accountID: accountID,
                name: displayName,
                method: .geminiAPIKey,
                email: normalizedNonEmpty(email),
                markActive: true,
                updateLastLoginAt: true
            )
        case .vertexAI:
            let normalizedProject = normalizedNonEmpty(project)
            let normalizedLocation = normalizedNonEmpty(location)
            guard normalizedProject != nil, normalizedLocation != nil else {
                throw NolonCoreCLIError.invalidArguments("Vertex requires --project and --location.")
            }
            let effectiveGoogleKey = normalizedNonEmpty(googleAPIKey) ?? normalizedNonEmpty(ProcessInfo.processInfo.environment["GOOGLE_API_KEY"])
            guard useADC || effectiveGoogleKey != nil else {
                throw NolonCoreCLIError.invalidArguments("Vertex requires --use-adc or --google-api-key/GOOGLE_API_KEY.")
            }
            _ = try await store.upsertAccount(
                provider: provider,
                accountID: accountID,
                name: displayName,
                method: .vertexAI,
                email: normalizedNonEmpty(email),
                project: normalizedProject,
                location: normalizedLocation,
                markActive: true,
                updateLastLoginAt: true
            )
        }

        let accounts = try await store.listAccounts(provider: provider)
        let activeID = try await activeGeminiAccountID(provider: provider)
        return GeminiAuthMutationPayload(
            provider: provider.rawValue,
            action: "login",
            method: method.rawValue,
            accountID: accountID.uuidString.lowercased(),
            activeAccountID: activeID?.uuidString.lowercased(),
            accountCount: accounts.count,
            loginURL: loginURL
        )
    }

    func geminiAuthActivate(provider: UsageProvider, accountID: String) async throws -> GeminiAuthMutationPayload {
        guard let targetID = UUID(uuidString: accountID) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --account-id. Expected UUID format.")
        }
        let account = try await geminiAuthStore().activate(provider: provider, accountID: targetID)
        _ = try await geminiAuthStore().upsertAccount(
            provider: provider,
            accountID: account.id,
            name: account.name,
            method: account.method,
            email: account.email,
            project: account.project,
            location: account.location,
            markActive: true,
            updateLastLoginAt: false
        )
        let accounts = try await geminiAuthStore().listAccounts(provider: provider)
        return GeminiAuthMutationPayload(
            provider: provider.rawValue,
            action: "activate",
            method: account.method.rawValue,
            accountID: targetID.uuidString.lowercased(),
            activeAccountID: targetID.uuidString.lowercased(),
            accountCount: accounts.count,
            loginURL: nil
        )
    }

    func geminiAuthDelete(provider: UsageProvider, accountID: String) async throws -> GeminiAuthMutationPayload {
        guard let targetID = UUID(uuidString: accountID) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --account-id. Expected UUID format.")
        }
        try await geminiAuthStore().delete(provider: provider, accountID: targetID)
        let accounts = try await geminiAuthStore().listAccounts(provider: provider)
        let activeID = try await activeGeminiAccountID(provider: provider)
        return GeminiAuthMutationPayload(
            provider: provider.rawValue,
            action: "delete",
            method: nil,
            accountID: targetID.uuidString.lowercased(),
            activeAccountID: activeID?.uuidString.lowercased(),
            accountCount: accounts.count,
            loginURL: nil
        )
    }

    @discardableResult
    func touchActiveGeminiAccount(provider: UsageProvider) async throws -> UUID? {
        guard let active = try await geminiAuthStore().activeAccount(provider: provider) else {
            return nil
        }
        _ = try await geminiAuthStore().upsertAccount(
            provider: provider,
            accountID: active.id,
            name: active.name,
            method: active.method,
            email: active.email,
            project: active.project,
            location: active.location,
            markActive: true,
            updateLastLoginAt: false
        )
        return active.id
    }

    func normalizedNonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func defaultFetchGeminiUsage(provider: UsageProvider) async -> [ProviderAccountUsageOutcome] {
        let tokenStore = FileTokenAccountStore(fileURL: ProviderUsagePaths.defaultTokenAccountsFileURL())
        let monitor = ProviderUsageMonitorService(tokenAccountStore: tokenStore)
        let settings = ProviderUsageMonitorSettings(
            sourceMode: .cli,
            includeCredits: false,
            webTimeoutSeconds: 15,
            autoRefreshIntervalMinutes: 0,
            costWindowDays: nil
        )
        return await monitor.fetchOutcomes(provider: provider, settings: settings, costWindowDays: nil)
    }

    func fetchGeminiUsage(provider: UsageProvider) async -> [ProviderAccountUsageOutcome] {
        await geminiUsageFetchAction(provider)
    }

    func fetchGeminiTokenTrend(provider: UsageProvider) async -> ProviderTokenTrendSnapshot? {
        try? await geminiTokenTrendFetchAction(provider)
    }

    func makeGeminiUsageEntries(_ outcomes: [ProviderAccountUsageOutcome]) -> [GeminiUsageEntry] {
        let formatter = ISO8601DateFormatter()
        return outcomes.map { outcome in
            let accountLabel: String = {
                switch outcome.account {
                case .default:
                    return "default"
                case let .tokenAccount(account):
                    return account.displayName
                }
            }()

            switch outcome.outcome.result {
            case let .success(result):
                return GeminiUsageEntry(
                    account: accountLabel,
                    status: "ok",
                    source: result.sourceLabel,
                    windows: result.usage.allWindows.map { window in
                        GeminiUsageWindowEntry(
                            id: window.id,
                            title: window.title,
                            usedPercent: window.window.usedPercent,
                            remainingPercent: window.window.remainingPercent,
                            resetsAt: window.window.resetsAt.map(formatter.string)
                        )
                    },
                    primaryUsedPercent: result.usage.primary?.usedPercent,
                    secondaryUsedPercent: result.usage.secondary?.usedPercent,
                    updatedAt: formatter.string(from: result.usage.updatedAt),
                    errorCode: nil,
                    error: nil
                )
            case let .failure(error):
                return GeminiUsageEntry(
                    account: accountLabel,
                    status: "failed",
                    source: nil,
                    windows: nil,
                    primaryUsedPercent: nil,
                    secondaryUsedPercent: nil,
                    updatedAt: nil,
                    errorCode: geminiUsageErrorCode(error),
                    error: error.localizedDescription
                )
            }
        }
    }

    func makeGeminiTokenTrendEntry(_ snapshot: ProviderTokenTrendSnapshot) -> GeminiTokenTrendEntry {
        GeminiTokenTrendEntry(
            todayTokens: snapshot.todayTokens,
            last7DaysTokens: snapshot.last7DaysTokens,
            last30DaysTokens: snapshot.last30DaysTokens,
            updatedAt: ISO8601DateFormatter().string(from: snapshot.updatedAt),
            source: snapshot.sourceLabel,
            points: snapshot.points.map { point in
                GeminiTokenTrendPointEntry(
                    date: point.date,
                    totalTokens: point.totalTokens,
                    inputTokens: point.inputTokens,
                    outputTokens: point.outputTokens,
                    cacheReadTokens: point.cacheReadTokens
                )
            }
        )
    }

    func geminiUsageErrorCode(_ error: Error) -> String? {
        guard let providerError = error as? ProviderUsageError else {
            return nil
        }
        switch providerError {
        case .unsupported:
            return "unsupported"
        case .missingToken:
            return "missing_token"
        case .missingAccount:
            return "missing_account"
        case .authExpired:
            return "auth_expired"
        }
    }

    func classifyGeminiUsageIssue(errorCode: String?, errorMessage: String) -> GeminiUsageDoctorIssueCode {
        if let errorCode {
            switch errorCode {
            case "unsupported":
                return .unsupported
            case "missing_token", "missing_account", "auth_expired":
                return .auth
            default:
                break
            }
        }

        let normalized = errorMessage.lowercased()
        if normalized.contains("timeout") || normalized.contains("timed out") {
            return .timeout
        }
        if normalized.contains("unauthorized")
            || normalized.contains("forbidden")
            || normalized.contains("401")
            || normalized.contains("403")
            || normalized.contains("auth")
            || normalized.contains("token")
            || normalized.contains("login")
        {
            return .auth
        }
        if normalized.contains("parse")
            || normalized.contains("decode")
            || normalized.contains("json")
            || normalized.contains("format")
            || normalized.contains("invalid")
        {
            return .parse
        }
        if normalized.contains("binary")
            || normalized.contains("executable")
            || normalized.contains("command not found")
            || normalized.contains("no such file")
            || normalized.contains("not found")
        {
            return .binary
        }
        return .unknown
    }

    func diagnoseGeminiUsage(_ outcomes: [ProviderAccountUsageOutcome]) -> (healthy: Bool, issues: [String], hints: [String], diagnostics: [GeminiUsageDoctorIssue]) {
        let entries = makeGeminiUsageEntries(outcomes)
        let failures = entries.filter { $0.status != "ok" }
        if failures.isEmpty {
            return (true, [], [], [])
        }

        var diagnostics: [GeminiUsageDoctorIssue] = []
        for entry in failures {
            guard let message = entry.error, !message.isEmpty else { continue }
            let code = classifyGeminiUsageIssue(errorCode: entry.errorCode, errorMessage: message)
            diagnostics.append(
                GeminiUsageDoctorIssue(
                    account: entry.account,
                    code: code,
                    message: message
                )
            )
        }

        let issues = diagnostics.map { "\($0.account) [\($0.code.rawValue)]: \($0.message)" }

        var hints: [String] = []
        for diagnostic in diagnostics {
            switch diagnostic.code {
            case .binary:
                hints.append("检查 Gemini 相关 CLI 二进制是否可执行且在 PATH 中。")
            case .auth:
                hints.append("检查 Gemini 登录态是否有效，必要时执行 `nolon gemini auth login --provider <gemini|antigravity> --method oauth-personal`。")
            case .parse:
                hints.append("检查 usage 返回格式是否可解析。")
            case .timeout:
                hints.append("出现超时，稍后重试并检查网络连接。")
            case .unsupported:
                hints.append("当前 provider 暂未支持该 usage 读取路径。")
            case .unknown:
                hints.append("查看错误原文并重试，必要时开启 --json 获取完整诊断。")
            }
        }
        let dedupedHints = hints.reduce(into: [String]()) { partial, hint in
            if !partial.contains(hint) {
                partial.append(hint)
            }
        }
        return (false, issues, dedupedHints, diagnostics)
    }

    func formatGeminiAuthListText(
        provider: UsageProvider,
        activeAccountID: UUID?,
        accounts: [GeminiAuthAccountView]
    ) -> String {
        var lines: [String] = []
        lines.append("provider: \(provider.rawValue)")
        lines.append("active_account_id: \(activeAccountID?.uuidString.lowercased() ?? "-")")
        lines.append("account_count: \(accounts.count)")
        guard !accounts.isEmpty else {
            lines.append("accounts: []")
            return lines.joined(separator: "\n")
        }
        let formatter = ISO8601DateFormatter()
        for account in accounts {
            let createdAt = formatter.string(from: account.createdAt)
            let lastUsed = account.lastUsedAt.map { formatter.string(from: $0) } ?? "-"
            let marker = account.isActive ? "*" : "-"
            lines.append("\(marker) \(account.id) \(account.label) method=\(account.method) created_at=\(createdAt) last_used=\(lastUsed)")
        }
        return lines.joined(separator: "\n")
    }

    func formatGeminiAuthStatusText(
        provider: UsageProvider,
        accountCount: Int,
        activeAccountID: UUID?
    ) -> String {
        [
            "provider: \(provider.rawValue)",
            "account_count: \(accountCount)",
            "active_account_id: \(activeAccountID?.uuidString.lowercased() ?? "-")",
        ].joined(separator: "\n")
    }

    func formatGeminiAuthMutationText(result: GeminiAuthMutationPayload) -> String {
        [
            "provider: \(result.provider)",
            "action: \(result.action)",
            "method: \(result.method ?? "-")",
            "account_id: \(result.accountID ?? "-")",
            "active_account_id: \(result.activeAccountID ?? "-")",
            "account_count: \(result.accountCount)",
            "login_url: \(result.loginURL ?? "-")",
        ].joined(separator: "\n")
    }

    func formatGeminiUsageText(
        provider: UsageProvider,
        entries: [GeminiUsageEntry],
        tokenTrend: GeminiTokenTrendEntry?
    ) -> String {
        var lines: [String] = []
        lines.append("provider: \(provider.rawValue)")
        if let tokenTrend {
            let today = tokenTrend.todayTokens.map(String.init) ?? "-"
            let last7 = tokenTrend.last7DaysTokens.map(String.init) ?? "-"
            let last30 = tokenTrend.last30DaysTokens.map(String.init) ?? "-"
            lines.append("token_trend: today=\(today) last7=\(last7) last30=\(last30) updated_at=\(tokenTrend.updatedAt) source=\(tokenTrend.source)")
        }
        if entries.isEmpty {
            lines.append("status: no data")
            return lines.joined(separator: "\n")
        }
        for entry in entries {
            let primary = entry.primaryUsedPercent.map { String(format: "%.0f%%", $0) } ?? "-"
            let secondary = entry.secondaryUsedPercent.map { String(format: "%.0f%%", $0) } ?? "-"
            let updatedAt = entry.updatedAt ?? "-"
            let suffix = entry.error.map { " error=\($0)" } ?? ""
            lines.append("[\(entry.status)] account=\(entry.account) primary=\(primary) secondary=\(secondary) updated_at=\(updatedAt)\(suffix)")
            if let windows = entry.windows, !windows.isEmpty {
                for window in windows {
                    let remaining = String(format: "%.0f%%", window.remainingPercent)
                    let reset = window.resetsAt ?? "-"
                    lines.append("  - \(window.title): remaining=\(remaining) resets_at=\(reset)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    func formatGeminiUsageDoctorText(provider: UsageProvider, diagnosis: (healthy: Bool, issues: [String], hints: [String], diagnostics: [GeminiUsageDoctorIssue])) -> String {
        var lines: [String] = []
        lines.append("provider: \(provider.rawValue)")
        lines.append("healthy: \(diagnosis.healthy ? "yes" : "no")")
        if !diagnosis.diagnostics.isEmpty {
            lines.append("issues:")
            lines.append(contentsOf: diagnosis.diagnostics.map { "- [\($0.code.rawValue)] \($0.account): \($0.message)" })
        }
        if !diagnosis.hints.isEmpty {
            lines.append("hints:")
            lines.append(contentsOf: diagnosis.hints.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }


}

struct GeminiUsageEntry: Encodable, Sendable {
    let account: String
    let status: String
    let source: String?
    let windows: [GeminiUsageWindowEntry]?
    let primaryUsedPercent: Double?
    let secondaryUsedPercent: Double?
    let updatedAt: String?
    let errorCode: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case account
        case status
        case source
        case windows
        case primaryUsedPercent = "primary_used_percent"
        case secondaryUsedPercent = "secondary_used_percent"
        case updatedAt = "updated_at"
        case errorCode = "error_code"
        case error
    }
}

struct GeminiUsageWindowEntry: Encodable, Sendable {
    let id: String
    let title: String
    let usedPercent: Double
    let remainingPercent: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case usedPercent = "used_percent"
        case remainingPercent = "remaining_percent"
        case resetsAt = "resets_at"
    }
}

struct GeminiTokenTrendEntry: Encodable, Sendable {
    let todayTokens: Int?
    let last7DaysTokens: Int?
    let last30DaysTokens: Int?
    let updatedAt: String
    let source: String
    let points: [GeminiTokenTrendPointEntry]

    enum CodingKeys: String, CodingKey {
        case todayTokens = "today_tokens"
        case last7DaysTokens = "last_7_days_tokens"
        case last30DaysTokens = "last_30_days_tokens"
        case updatedAt = "updated_at"
        case source
        case points
    }
}

struct GeminiTokenTrendPointEntry: Encodable, Sendable {
    let date: String
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int

    enum CodingKeys: String, CodingKey {
        case date
        case totalTokens = "total_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens"
    }
}

struct GeminiAuthAccountView: Encodable, Sendable {
    let id: String
    let label: String
    let method: String
    let isActive: Bool
    let createdAt: Date
    let lastUsedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case method
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
    }
}

struct GeminiAuthListPayload: Encodable, Sendable {
    let provider: String
    let activeAccountID: String?
    let accounts: [GeminiAuthAccountView]

    enum CodingKeys: String, CodingKey {
        case provider
        case activeAccountID = "active_account_id"
        case accounts
    }
}

struct GeminiAuthStatusPayload: Encodable, Sendable {
    let provider: String
    let accountCount: Int
    let activeAccountID: String?

    enum CodingKeys: String, CodingKey {
        case provider
        case accountCount = "account_count"
        case activeAccountID = "active_account_id"
    }
}

struct GeminiAuthMutationPayload: Encodable, Sendable {
    let provider: String
    let action: String
    let method: String?
    let accountID: String?
    let activeAccountID: String?
    let accountCount: Int
    let loginURL: String?

    enum CodingKeys: String, CodingKey {
        case provider
        case action
        case method
        case accountID = "account_id"
        case activeAccountID = "active_account_id"
        case accountCount = "account_count"
        case loginURL = "login_url"
    }
}

struct GeminiUsagePayload: Encodable, Sendable {
    let provider: String
    let refreshed: Bool
    let activeAccountID: String?
    let entries: [GeminiUsageEntry]
    let tokenTrend: GeminiTokenTrendEntry?

    enum CodingKeys: String, CodingKey {
        case provider
        case refreshed
        case activeAccountID = "active_account_id"
        case entries
        case tokenTrend = "token_trend"
    }
}

struct GeminiUsageDoctorPayload: Encodable, Sendable {
    let provider: String
    let healthy: Bool
    let issues: [String]
    let hints: [String]
    let diagnostics: [GeminiUsageDoctorIssue]
}

struct GeminiUsageDoctorIssue: Encodable, Sendable {
    let account: String
    let code: GeminiUsageDoctorIssueCode
    let message: String
}

enum GeminiUsageDoctorIssueCode: String, Encodable, Sendable {
    case binary
    case auth
    case parse
    case timeout
    case unsupported
    case unknown
}
