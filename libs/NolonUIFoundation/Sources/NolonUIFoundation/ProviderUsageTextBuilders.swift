import Foundation

public enum ProviderUsageTextBuilders {
    public static func sourceModeDisplayName(id: String) -> String {
        switch id {
        case "auto":
            return NSLocalizedString("usage.monitor.source_mode.auto", value: "Auto", comment: "Auto")
        case "cli":
            return NSLocalizedString("usage.monitor.source_mode.cli", value: "CLI", comment: "CLI")
        case "web":
            return NSLocalizedString("usage.monitor.source_mode.web", value: "Web", comment: "Web")
        case "oauth":
            return NSLocalizedString("usage.monitor.source_mode.oauth", value: "OAuth", comment: "OAuth")
        case "apiToken":
            return NSLocalizedString("usage.monitor.source_mode.api_token", value: "API token", comment: "API token")
        case "localProbe":
            return NSLocalizedString("usage.monitor.source_mode.local_probe", value: "Local probe", comment: "Local probe")
        case "webDashboard":
            return NSLocalizedString("usage.monitor.source_mode.web_dashboard", value: "Web dashboard", comment: "Web dashboard")
        default:
            return id
        }
    }

    public static func autoRefreshTitle(minutes: Int) -> String {
        switch minutes {
        case 0:
            return NSLocalizedString("usage.monitor.auto_refresh.off", value: "Off", comment: "Auto refresh off")
        case 5:
            return NSLocalizedString("usage.monitor.auto_refresh.5m", value: "5m", comment: "Auto refresh 5 minutes")
        case 15:
            return NSLocalizedString("usage.monitor.auto_refresh.15m", value: "15m", comment: "Auto refresh 15 minutes")
        case 30:
            return NSLocalizedString("usage.monitor.auto_refresh.30m", value: "30m", comment: "Auto refresh 30 minutes")
        case 120:
            return NSLocalizedString("usage.monitor.auto_refresh.2h", value: "2h", comment: "Auto refresh 2 hours")
        case 300:
            return NSLocalizedString("usage.monitor.auto_refresh.5h", value: "5h", comment: "Auto refresh 5 hours")
        default:
            return "\(minutes)m"
        }
    }
}
