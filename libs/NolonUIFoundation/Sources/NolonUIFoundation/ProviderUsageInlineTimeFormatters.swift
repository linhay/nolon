import Foundation

public enum ProviderUsageInlineTimeFormatters {
    public enum SyncDisplay: Equatable {
        case justNow
        case relative(String)
        case absolute(String)
    }

    public static func loginTimestamp(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    public static func syncDisplay(
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

    public static func joinInlineTimeLine(loginSegment: String?, syncSegment: String?) -> String? {
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
