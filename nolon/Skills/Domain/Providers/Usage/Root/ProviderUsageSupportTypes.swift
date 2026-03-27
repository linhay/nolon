import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
import Foundation
import NolonUIFoundation

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
        case .auto: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "auto")
        case .cli: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "cli")
        case .web: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "web")
        case .oauth: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "oauth")
        case .apiToken: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "apiToken")
        case .localProbe: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "localProbe")
        case .webDashboard: return ProviderUsageTextBuilders.sourceModeDisplayName(id: "webDashboard")
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
        ProviderUsageTextBuilders.autoRefreshTitle(minutes: rawValue)
    }
}

enum CodexAccountInlineTimeFormatter {
    typealias SyncDisplay = ProviderUsageInlineTimeFormatters.SyncDisplay

    static func loginTimestamp(_ date: Date, timeZone: TimeZone = .current) -> String {
        ProviderUsageInlineTimeFormatters.loginTimestamp(date, timeZone: timeZone)
    }

    static func syncDisplay(
        since syncAt: Date,
        now: Date = Date(),
        isChinese: Bool,
        timeZone: TimeZone = .current
    ) -> SyncDisplay {
        ProviderUsageInlineTimeFormatters.syncDisplay(
            since: syncAt,
            now: now,
            isChinese: isChinese,
            timeZone: timeZone
        )
    }

    static func joinInlineTimeLine(loginSegment: String?, syncSegment: String?) -> String? {
        ProviderUsageInlineTimeFormatters.joinInlineTimeLine(
            loginSegment: loginSegment,
            syncSegment: syncSegment
        )
    }
}

enum CodexAccountDisplayNameResolver {
    static func resolve(
        summary: CodexAuthSummary?,
        relativeAuthPath: String?,
        defaultName: String,
        accountID: UUID?
    ) -> String {
        ProviderUsageAccountDisplayNameResolver.resolve(
            email: summary?.email,
            summaryAccountID: summary?.accountID,
            cardKind: summary.map { "\($0.cardKind)" },
            apiKeySuffix: summary?.apiKeySuffix,
            relayModelProvider: summary?.relayModelProvider,
            relayBaseURL: summary?.relayBaseURL,
            relativeAuthPath: relativeAuthPath,
            defaultName: defaultName,
            accountID: accountID
        )
    }
}

enum TokenCountCompactFormatter {
    static func format(_ value: Int) -> String {
        TokenCountFormatters.compact(value)
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
