import Foundation

public enum ResourceListGuidancePolicy {
    public static func emptyResultLine(
        resourceDisplayLabel: String,
        providerFilter: String?,
        stateFilterLabel: String?,
        orphanedLabel: String = "失效链接"
    ) -> String {
        if let filter = providerFilter, !filter.isEmpty, let state = stateFilterLabel, !state.isEmpty {
            return "在 provider=\(filter) 且 state=\(state) 下，未发现匹配\(resourceDisplayLabel)。"
        }
        if let filter = providerFilter, !filter.isEmpty {
            return "在 provider=\(filter) 下，未发现异常\(resourceDisplayLabel)（\(orphanedLabel)/损坏）。"
        }
        if let state = stateFilterLabel, !state.isEmpty {
            return "在 state=\(state) 下，未发现匹配\(resourceDisplayLabel)。"
        }
        return "未发现异常\(resourceDisplayLabel)（\(orphanedLabel)/损坏）。"
    }

    public static func installedHintLine(
        resourceDisplayLabel: String,
        command: String
    ) -> String {
        "如需查看已安装\(resourceDisplayLabel)，请执行: `\(command)`"
    }

    public static func noFixesRetryLines(command: String) -> [String] {
        [
            "当前筛选条件下无可修复项；请移除筛选后重试 --show-fixes。",
            "复检命令: `\(command)`",
        ]
    }

    public static func verboseHintLine(command: String) -> String {
        "提示: 使用 `\(command)` 查看安装路径与来源。"
    }

    public static func skillsQuickActionItems(
        hasBroken: Bool,
        hasOrphaned: Bool,
        listCommandPrefix: String = "nolon skills list"
    ) -> [String] {
        var actions: [String] = []
        if hasBroken {
            actions.append("查看损坏详情: `\(listCommandPrefix) --state broken --verbose`")
        }
        if hasOrphaned {
            actions.append("查看失效链接详情: `\(listCommandPrefix) --state orphaned --verbose`")
        }
        actions.append("生成修复命令: `\(listCommandPrefix) --show-fixes`")
        return actions
    }
}
