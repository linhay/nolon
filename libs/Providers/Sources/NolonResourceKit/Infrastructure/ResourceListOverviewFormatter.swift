import Foundation

public struct ResourceListOverviewMetrics: Sendable, Equatable {
    public let installedCount: Int
    public let orphanedCount: Int
    public let brokenCount: Int
    public let itemCount: Int

    public init(
        installedCount: Int,
        orphanedCount: Int,
        brokenCount: Int,
        itemCount: Int
    ) {
        self.installedCount = installedCount
        self.orphanedCount = orphanedCount
        self.brokenCount = brokenCount
        self.itemCount = itemCount
    }
}

public enum ResourceListOverviewFormatter {
    public static func issueCount(_ metrics: ResourceListOverviewMetrics) -> Int {
        metrics.orphanedCount + metrics.brokenCount
    }

    public static func percent(_ value: Int, total: Int) -> String {
        guard total > 0 else { return "0.0%" }
        let ratio = (Double(value) / Double(total)) * 100
        return String(format: "%.1f%%", ratio)
    }

    public static func compactHealthySummary(
        showFixes: Bool,
        verbose: Bool,
        hasProviderFilter: Bool,
        hasStateFilter: Bool,
        metrics: ResourceListOverviewMetrics
    ) -> Bool {
        showFixes
            && issueCount(metrics) == 0
            && !verbose
            && !hasProviderFilter
            && !hasStateFilter
    }

    public static func summaryLine(
        showFixes: Bool,
        metrics: ResourceListOverviewMetrics
    ) -> String? {
        guard showFixes else { return nil }
        let actionLabel = issueCount(metrics) > 0 ? "需修复" : "无"
        return "摘要: 异常=\(issueCount(metrics)) | 已安装=\(metrics.installedCount)/\(metrics.itemCount) | 修复动作=\(actionLabel)"
    }

    public static func statusLine(
        metrics: ResourceListOverviewMetrics,
        orphanedLabel: String = "失效链接"
    ) -> String {
        let installedPct = percent(metrics.installedCount, total: metrics.itemCount)
        let orphanedPct = percent(metrics.orphanedCount, total: metrics.itemCount)
        let brokenPct = percent(metrics.brokenCount, total: metrics.itemCount)
        return "状态(已安装/\(orphanedLabel)/损坏): \(metrics.installedCount)/\(metrics.orphanedCount)/\(metrics.brokenCount) (\(installedPct)/\(orphanedPct)/\(brokenPct))"
    }

    public static func conclusionLines(
        showFixes: Bool,
        metrics: ResourceListOverviewMetrics,
        orphanedLabel: String = "失效链接"
    ) -> [String] {
        let issues = issueCount(metrics)
        if showFixes {
            if issues > 0 {
                return ["结论：发现 \(issues) 项异常（\(orphanedLabel) \(metrics.orphanedCount)、损坏 \(metrics.brokenCount)），请按下方修复计划依序处理。"]
            }
            let installedPct = percent(metrics.installedCount, total: metrics.itemCount)
            return ["健康：\(metrics.installedCount)/\(metrics.itemCount)（\(installedPct)），异常 0，修复动作：无。"]
        }

        var lines: [String] = []
        lines.append("需处理异常: \(issues)（\(orphanedLabel) \(metrics.orphanedCount)，损坏 \(metrics.brokenCount)）")
        if issues > 0 {
            lines.append("行动建议: 需处理 \(issues) 项异常（高优先级）")
        } else {
            lines.append("行动建议: 无需处理（系统健康）")
        }
        return lines
    }
}
