import Foundation

public enum UsageRefreshPolicy {
    public static func shouldRefresh(
        hasTriggeredAppearRefresh: Bool,
        intervalMinutes: Int,
        lastRefreshAt: Date?,
        now: Date = Date()
    ) -> Bool {
        if !hasTriggeredAppearRefresh {
            return true
        }
        let intervalSeconds = TimeInterval(max(0, intervalMinutes)) * 60
        if intervalSeconds == 0 {
            return true
        }
        guard let lastRefreshAt else {
            return true
        }
        return now.timeIntervalSince(lastRefreshAt) >= intervalSeconds
    }
}
