import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
import Foundation

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension ProviderSourceMode {
    var displayName: String {
        switch self {
        case .auto: return NSLocalizedString("usage.monitor.source_mode.auto", value: "Auto", comment: "Auto")
        case .cli: return NSLocalizedString("usage.monitor.source_mode.cli", value: "CLI", comment: "CLI")
        case .web: return NSLocalizedString("usage.monitor.source_mode.web", value: "Web", comment: "Web")
        case .oauth: return NSLocalizedString("usage.monitor.source_mode.oauth", value: "OAuth", comment: "OAuth")
        case .apiToken: return NSLocalizedString("usage.monitor.source_mode.api_token", value: "API token", comment: "API token")
        case .localProbe: return NSLocalizedString("usage.monitor.source_mode.local_probe", value: "Local probe", comment: "Local probe")
        case .webDashboard: return NSLocalizedString("usage.monitor.source_mode.web_dashboard", value: "Web dashboard", comment: "Web dashboard")
        }
    }
}

enum UsageAutoRefreshInterval: Int, CaseIterable, Identifiable {
    case off = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case twoHours = 120
    case fiveHours = 300

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off:
            return NSLocalizedString("usage.monitor.auto_refresh.off", value: "Off", comment: "Auto refresh off")
        case .fiveMinutes:
            return NSLocalizedString("usage.monitor.auto_refresh.5m", value: "5m", comment: "Auto refresh 5 minutes")
        case .fifteenMinutes:
            return NSLocalizedString("usage.monitor.auto_refresh.15m", value: "15m", comment: "Auto refresh 15 minutes")
        case .thirtyMinutes:
            return NSLocalizedString("usage.monitor.auto_refresh.30m", value: "30m", comment: "Auto refresh 30 minutes")
        case .twoHours:
            return NSLocalizedString("usage.monitor.auto_refresh.2h", value: "2h", comment: "Auto refresh 2 hours")
        case .fiveHours:
            return NSLocalizedString("usage.monitor.auto_refresh.5h", value: "5h", comment: "Auto refresh 5 hours")
        }
    }
}

enum CodexAccountInlineTimeFormatter {
    enum SyncDisplay: Equatable {
        case justNow
        case relative(String)
        case absolute(String)
    }

    static func loginTimestamp(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    static func syncDisplay(
        since syncAt: Date,
        now: Date = Date(),
        isChinese: Bool,
        timeZone: TimeZone = .current
    ) -> SyncDisplay {
        let seconds = max(0, Int(now.timeIntervalSince(syncAt).rounded(.down)))
        if seconds < 60 {
            return .justNow
        }

        if seconds < 3600 {
            let minutes = max(1, seconds / 60)
            return .relative(isChinese ? "\(minutes)分钟" : "\(minutes)m")
        }

        if seconds < 86_400 {
            let totalMinutes = seconds / 60
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return .relative(isChinese ? "\(hours)小时" : "\(hours)h")
            }
            return .relative(isChinese ? "\(hours)小时\(minutes)分" : "\(hours)h\(minutes)m")
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MM/dd HH:mm"
        return .absolute(formatter.string(from: syncAt))
    }

    static func joinInlineTimeLine(loginSegment: String?, syncSegment: String?) -> String? {
        let login = loginSegment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sync = syncSegment?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (login?.isEmpty == false ? login : nil, sync?.isEmpty == false ? sync : nil) {
        case let (login?, sync?):
            return "\(login) · \(sync)"
        case let (login?, nil):
            return login
        case let (nil, sync?):
            return sync
        case (nil, nil):
            return nil
        }
    }
}

enum CodexAccountDisplayNameResolver {
    static func resolve(
        summary: CodexAuthSummary?,
        relativeAuthPath: String?,
        defaultName: String,
        accountID: UUID?
    ) -> String {
        if let summary {
            let email = summary.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let email, !email.isEmpty {
                return email
            }

            switch summary.cardKind {
            case .chatgptAccount:
                let summaryAccountID = summary.accountID?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let summaryAccountID, !summaryAccountID.isEmpty {
                    return summaryAccountID
                }
            case .officialAPIKey:
                if let suffix = normalizedKeySuffix(summary.apiKeySuffix) {
                    return "key-\(suffix)"
                }
            case .relayProfile:
                let provider = summary.relayModelProvider?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let provider, !provider.isEmpty {
                    return provider
                }
                if let host = relayHost(summary.relayBaseURL) {
                    return host
                }
                if let suffix = normalizedKeySuffix(summary.apiKeySuffix) {
                    return "key-\(suffix)"
                }
            case .none:
                if let suffix = normalizedKeySuffix(summary.apiKeySuffix) {
                    return "key-\(suffix)"
                }
            }
        }

        if let fallbackStem = fallbackFileStem(relativeAuthPath) {
            return fallbackStem
        }

        let normalizedDefaultName = defaultName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedDefaultName.isEmpty {
            return normalizedDefaultName
        }

        if let accountID {
            return accountID.uuidString
        }
        return "account"
    }

    private static func fallbackFileStem(_ relativeAuthPath: String?) -> String? {
        guard let relativeAuthPath else { return nil }
        let trimmed = relativeAuthPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stem = URL(fileURLWithPath: trimmed).deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stem.isEmpty ? nil : stem
    }

    private static func relayHost(_ baseURL: String?) -> String? {
        guard let baseURL = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !baseURL.isEmpty,
              let host = URL(string: baseURL)?.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty
        else {
            return nil
        }
        return host
    }

    private static func normalizedKeySuffix(_ suffix: String?) -> String? {
        guard let suffix = suffix?.trimmingCharacters(in: .whitespacesAndNewlines),
              !suffix.isEmpty
        else {
            return nil
        }
        return suffix
    }
}

enum TokenCountCompactFormatter {
    static func format(_ value: Int) -> String {
        if value >= 100_000_000 {
            return String(format: "%.1f亿", Double(value) / 100_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

enum UsageIssueCode: String, Equatable {
    case binary
    case auth
    case parse
    case timeout
    case unsupported
    case unknown
}

enum UsageIssueClassifier {
    static func classify(provider: UsageProvider, error: Error) -> UsageIssueCode {
        if let usageError = error as? ProviderUsageError {
            switch usageError {
            case .unsupported:
                return .unsupported
            case .missingToken:
                return .auth
            case .missingAccount:
                return .auth
            case .authExpired:
                return .auth
            }
        }

        let text = normalized(error.localizedDescription)
        if text.contains("timeout") || text.contains("timed out") {
            return .timeout
        }
        if text.contains("unauthorized")
            || text.contains("forbidden")
            || text.contains("401")
            || text.contains("403")
            || text.contains("auth")
            || text.contains("token")
            || text.contains("login")
        {
            return .auth
        }
        if text.contains("parse")
            || text.contains("decode")
            || text.contains("json")
            || text.contains("format")
            || text.contains("invalid")
        {
            return .parse
        }
        if text.contains("binary")
            || text.contains("executable")
            || text.contains("command not found")
            || text.contains("no such file")
            || text.contains("not found")
        {
            return .binary
        }
        if isGeminiFamily(provider: provider) {
            return .unsupported
        }
        return .unknown
    }

    static func hints(provider: UsageProvider, code: UsageIssueCode) -> [String] {
        var values: [String] = []
        switch code {
        case .binary:
            values.append("检查相关 CLI 二进制是否可执行并在 PATH 中。")
        case .auth:
            values.append("检查登录态是否有效，必要时重新执行登录。")
        case .parse:
            values.append("检查 usage 返回格式是否可解析。")
        case .timeout:
            values.append("出现超时，请稍后重试并检查网络连接。")
        case .unsupported:
            values.append("当前 provider 暂未支持该 usage 读取路径。")
        case .unknown:
            values.append("查看错误原文并重试。")
        }

        if provider == .gemini {
            values.append("可尝试点击顶部“登录”重新走 Gemini OAuth。")
        } else if provider == .antigravity {
            values.append("可尝试点击顶部“登录”重新走 Antigravity OAuth。")
        }
        return values
    }

    static func isGeminiFamily(provider: UsageProvider) -> Bool {
        provider == .gemini || provider == .antigravity
    }

    private static func normalized(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
