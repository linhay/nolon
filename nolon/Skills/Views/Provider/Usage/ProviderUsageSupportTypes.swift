import SwiftUI
import ProviderUsage

struct CostTableRow: Identifiable {
    let id: String
    let date: Date
    let dateLabel: String
    let costUSD: Double
    let tokens: Int
    let costText: String
    let tokensText: String
}

struct ParsedCostRow {
    let date: Date
    let costUSD: Double
    let tokens: Int?
}

struct CostMonthKey: Hashable {
    let year: Int
    let month: Int
    let date: Date

    init(date: Date) {
        let calendar = Calendar.current
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
        self.date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
    }
}

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

enum CostHistoryWindow: CaseIterable, Identifiable {
    case days30
    case days90
    case days180
    case days365
    case all

    var id: String {
        switch self {
        case .days30: return "30"
        case .days90: return "90"
        case .days180: return "180"
        case .days365: return "365"
        case .all: return "all"
        }
    }

    var days: Int? {
        switch self {
        case .days30: return 30
        case .days90: return 90
        case .days180: return 180
        case .days365: return 365
        case .all: return nil
        }
    }

    static func from(days: Int?) -> CostHistoryWindow {
        switch days {
        case 30: return .days30
        case 90: return .days90
        case 180: return .days180
        case 365: return .days365
        default: return .all
        }
    }

    var title: String {
        switch self {
        case .days30: return NSLocalizedString("usage.cost.chart.range.30d", value: "30D", comment: "Range 30 days")
        case .days90: return NSLocalizedString("usage.cost.chart.range.90d", value: "90D", comment: "Range 90 days")
        case .days180: return NSLocalizedString("usage.cost.chart.range.180d", value: "180D", comment: "Range 180 days")
        case .days365: return NSLocalizedString("usage.cost.chart.range.365d", value: "365D", comment: "Range 365 days")
        case .all: return NSLocalizedString("usage.cost.chart.range.all", value: "All", comment: "Range all")
        }
    }
}
