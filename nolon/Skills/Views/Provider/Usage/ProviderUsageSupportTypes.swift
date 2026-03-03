import SwiftUI
import ProviderUsage
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
