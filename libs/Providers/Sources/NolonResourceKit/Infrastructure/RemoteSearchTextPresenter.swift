import Foundation

public enum RemoteSearchPresentationKind: String, Sendable, Equatable {
    case workflow
    case mcp
}

public struct RemoteSearchPresentationItem: Sendable, Equatable {
    public let slug: String
    public let summary: String?
    public let latestVersion: String?
    public let updatedAt: Date?

    public init(slug: String, summary: String?, latestVersion: String?, updatedAt: Date?) {
        self.slug = slug
        self.summary = summary
        self.latestVersion = latestVersion
        self.updatedAt = updatedAt
    }
}

public struct RemoteSearchPresentationInput: Sendable, Equatable {
    public let kind: RemoteSearchPresentationKind
    public let baseURL: String
    public let query: String?
    public let items: [RemoteSearchPresentationItem]

    public init(kind: RemoteSearchPresentationKind, baseURL: String, query: String?, items: [RemoteSearchPresentationItem]) {
        self.kind = kind
        self.baseURL = baseURL
        self.query = query
        self.items = items
    }
}

public struct RemoteSearchTextPresenter: Sendable {
    public init() {}

    public func render(_ input: RemoteSearchPresentationInput) -> String {
        if input.items.isEmpty {
            return """
            未找到匹配 \(input.kind.rawValue)
            提示: 使用 `nolon \(input.kind.rawValue) sync --source <owner/repo>` 同步本地仓库后重试，或更换关键词。
            """
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let query = input.query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let queryPart = query.isEmpty ? "" : " (query: \(query))"
        let queryExample = query.isEmpty ? "<keyword>" : query
        let maxDisplay = 10
        let displayedItems = Array(input.items.prefix(maxDisplay))

        let lines = displayedItems.enumerated().map { index, item in
            var itemLines = [
                "[\(index + 1)] \(item.slug)",
                "  version: \(item.latestVersion ?? "-")",
                "  updated: \(item.updatedAt.map { formatUpdatedDate($0, formatter: formatter) } ?? "-")",
            ]
            if let summary = compactSummary(item.summary, maxLength: 140) {
                itemLines.append("  summary: \(summary)")
            }
            return itemLines.joined(separator: "\n")
        }.joined(separator: "\n\n")

        let truncatedHint = input.items.count > displayedItems.count
            ? "提示: 仅展示前 \(displayedItems.count) 条；可增大 `--limit` 查看更多。"
            : ""

        return """
        匹配结果: \(input.items.count)\(queryPart)
        source: remote-api (\(input.baseURL))
        安装:
        - 指定 provider: nolon \(input.kind.rawValue) add <slug> --provider codex --dry-run
        - 全部 providers: nolon \(input.kind.rawValue) add <slug> --dry-run [可能批量写入]
        - 搜索并挑选: nolon \(input.kind.rawValue) search \(queryExample) --install --pick 1 --provider codex --dry-run
        \(truncatedHint)
        \(lines)
        提示: 用 `--install --pick <序号>` 或直接 slug 安装。
        """
    }

    private func compactSummary(_ raw: String?, maxLength: Int) -> String? {
        guard let raw else { return nil }
        let compact = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return nil }
        guard compact.count > maxLength else { return compact }
        let prefix = compact.prefix(max(0, maxLength - 3))
        return "\(prefix)..."
    }

    private func formatUpdatedDate(_ date: Date, formatter: DateFormatter) -> String {
        let rendered = formatter.string(from: date)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        guard target > today else { return rendered }
        let dayDiff = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        guard dayDiff > 0 else { return rendered }
        return "\(rendered) (future +\(dayDiff)d)"
    }
}
