import Foundation

public enum ProviderQuotaSectionBuilders {
    public static func syncText(loginAt: Date?, syncedAt: Date?, now: Date = Date()) -> String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        var parts: [String] = []
        if let loginAt {
            let timeString = DateFormatter.localizedString(from: loginAt, dateStyle: .none, timeStyle: .short)
            parts.append(
                String(
                    format: NSLocalizedString("usage.sync.login", value: "LoggedIn %@", comment: "Login time"),
                    timeString
                )
            )
        }
        if let syncedAt {
            let relative = formatter.localizedString(for: syncedAt, relativeTo: now)
            parts.append(
                String(
                    format: NSLocalizedString("usage.sync.synced", value: "Synced %@", comment: "Sync time"),
                    relative
                )
            )
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public static func resetText(resetsAt: Date, now: Date = Date()) -> String {
        let remaining = resetsAt.timeIntervalSince(now)
        if remaining <= 0 {
            return NSLocalizedString("usage.reset.now", value: "now", comment: "reset now")
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        let duration = formatter.string(from: remaining) ?? ""
        return String(
            format: NSLocalizedString("usage.reset.suffix", value: "%@ left", comment: "reset suffix"),
            duration
        )
    }
}
