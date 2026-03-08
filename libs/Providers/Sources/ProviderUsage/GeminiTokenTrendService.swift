import Foundation
import CodexBarProviderCatalog

public struct GeminiTokenTrendService: Sendable {
    typealias LoadActiveAccount = @Sendable (UsageProvider) async throws -> GeminiAuthAccount?
    typealias LoadSessionRoot = @Sendable () -> URL?
    typealias ListSessionFiles = @Sendable (URL) throws -> [URL]
    typealias ReadFile = @Sendable (URL) throws -> String

    private let loadActiveAccount: LoadActiveAccount
    private let loadSessionRoot: LoadSessionRoot
    private let listSessionFiles: ListSessionFiles
    private let readFile: ReadFile
    private let now: @Sendable () -> Date

    public init() {
        let store = GeminiAuthStore.shared
        self.loadActiveAccount = { provider in
            try await store.activeAccount(provider: provider)
        }
        self.loadSessionRoot = Self.defaultSessionRoot
        self.listSessionFiles = Self.defaultListSessionFiles
        self.readFile = { url in
            try String(contentsOf: url, encoding: .utf8)
        }
        self.now = Date.init
    }

    init(
        loadActiveAccount: @escaping LoadActiveAccount,
        loadSessionRoot: @escaping LoadSessionRoot = { nil },
        listSessionFiles: @escaping ListSessionFiles,
        readFile: @escaping ReadFile,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loadActiveAccount = loadActiveAccount
        self.loadSessionRoot = loadSessionRoot
        self.listSessionFiles = listSessionFiles
        self.readFile = readFile
        self.now = now
    }

    public func fetchActiveSnapshot(
        provider: UsageProvider,
        trailingDays: Int? = nil
    ) async throws -> ProviderTokenTrendSnapshot? {
        guard let account = try await loadActiveAccount(provider) else {
            return nil
        }
        _ = account

        guard let sessionRoot = loadSessionRoot() else {
            return ProviderTokenTrendSnapshot(
                points: [],
                todayTokens: nil,
                last7DaysTokens: nil,
                last30DaysTokens: nil,
                updatedAt: now(),
                sourceLabel: "session"
            )
        }

        let sessionFiles = try listSessionFiles(sessionRoot)
        guard !sessionFiles.isEmpty else {
            return ProviderTokenTrendSnapshot(
                points: [],
                todayTokens: nil,
                last7DaysTokens: nil,
                last30DaysTokens: nil,
                updatedAt: now(),
                sourceLabel: "session"
            )
        }

        var daily: [String: DayTotals] = [:]
        for fileURL in sessionFiles {
            let raw = try readFile(fileURL)
            let record = try JSONDecoder().decode(GeminiConversationRecord.self, from: Data(raw.utf8))
            for message in record.messages where message.type == "gemini" {
                guard let tokens = message.tokens,
                      let day = Self.dayString(from: message.timestamp) else {
                    continue
                }
                var totals = daily[day, default: DayTotals()]
                totals.input += max(0, tokens.input)
                totals.output += max(0, tokens.output)
                totals.cached += max(0, tokens.cached)
                totals.total += max(0, tokens.total)
                daily[day] = totals
            }
        }

        var points = daily.keys.sorted().map { day in
            let totals = daily[day, default: DayTotals()]
            return ProviderTokenTrendPoint(
                date: day,
                totalTokens: totals.total,
                inputTokens: totals.input,
                outputTokens: totals.output,
                cacheReadTokens: totals.cached
            )
        }

        if let trailingDays, trailingDays > 0, points.count > trailingDays {
            points = Array(points.suffix(trailingDays))
        }

        let today = points.last?.totalTokens
        let last7 = sumTrailing(points: points, days: 7)
        let last30 = sumTrailing(points: points, days: 30)
        return ProviderTokenTrendSnapshot(
            points: points,
            todayTokens: today,
            last7DaysTokens: last7,
            last30DaysTokens: last30,
            updatedAt: now(),
            sourceLabel: "session"
        )
    }

    private func sumTrailing(points: [ProviderTokenTrendPoint], days: Int) -> Int? {
        guard days > 0, !points.isEmpty else { return nil }
        let values = points.suffix(days).map(\.totalTokens)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func dayString(from timestamp: String) -> String? {
        let trimmed = timestamp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return nil }
        let prefix = String(trimmed.prefix(10))
        return prefix.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil ? prefix : nil
    }

    private static func defaultListSessionFiles(root: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.lastPathComponent.hasPrefix("session-"),
                  item.pathExtension == "json",
                  item.path.contains("/tmp/"),
                  item.path.contains("/chats/") else {
                continue
            }
            files.append(item)
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func defaultSessionRoot() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        if let home = environment["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !home.isEmpty {
            return URL(fileURLWithPath: home, isDirectory: true)
                .appendingPathComponent(".gemini", isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini", isDirectory: true)
    }
}

private struct GeminiConversationRecord: Decodable {
    let messages: [GeminiConversationMessage]
}

private struct GeminiConversationMessage: Decodable {
    let type: String
    let timestamp: String
    let tokens: GeminiConversationTokens?
}

private struct GeminiConversationTokens: Decodable {
    let input: Int
    let output: Int
    let cached: Int
    let total: Int
}

private struct DayTotals {
    var input = 0
    var output = 0
    var cached = 0
    var total = 0
}
