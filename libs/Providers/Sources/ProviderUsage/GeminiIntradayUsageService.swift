import Foundation
import CodexBarProviderCatalog

public struct GeminiIntradayUsageService: Sendable {
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
        dayKey: String,
        bucket: ProviderIntradayBucket = .minute30,
        timezone: TimeZone = .current
    ) async throws -> ProviderIntradayUsageSnapshot? {
        guard let account = try await loadActiveAccount(provider) else {
            return nil
        }
        _ = account

        guard let range = Self.makeDayRange(dayKey: dayKey, timezone: timezone) else {
            return nil
        }

        guard let sessionRoot = loadSessionRoot() else {
            return Self.emptySnapshot(
                dayKey: dayKey,
                bucket: bucket,
                timezone: timezone,
                rangeStart: range.start,
                rangeEnd: range.end,
                fetchedAt: now()
            )
        }

        let sessionFiles = try listSessionFiles(sessionRoot)
        guard !sessionFiles.isEmpty else {
            return Self.emptySnapshot(
                dayKey: dayKey,
                bucket: bucket,
                timezone: timezone,
                rangeStart: range.start,
                rangeEnd: range.end,
                fetchedAt: now()
            )
        }

        let bucketSeconds = Self.bucketSeconds(for: bucket)
        let actualBucketCount = Int((range.end.timeIntervalSince(range.start) / bucketSeconds).rounded())
        var totals = Array(
            repeating: GeminiIntradayBucketTotals(),
            count: max(0, actualBucketCount)
        )

        for fileURL in sessionFiles {
            let raw = try readFile(fileURL)
            let record = try JSONDecoder().decode(GeminiIntradayConversationRecord.self, from: Data(raw.utf8))
            for message in record.messages where message.type == "gemini" {
                guard let tokens = message.tokens,
                      let timestamp = Self.parseISODate(message.timestamp),
                      timestamp >= range.start,
                      timestamp < range.end,
                      !totals.isEmpty else {
                    continue
                }

                let secondsSinceDayStart = timestamp.timeIntervalSince(range.start)
                let rawIndex = Int(secondsSinceDayStart / bucketSeconds)
                let bucketIndex = min(max(0, rawIndex), totals.count - 1)
                totals[bucketIndex].input += max(0, tokens.input)
                totals[bucketIndex].output += max(0, tokens.output)
                totals[bucketIndex].cached += max(0, tokens.cached)
                totals[bucketIndex].total += max(0, tokens.total)
            }
        }

        let points = totals.enumerated().map { index, item in
            let start = range.start.addingTimeInterval(Double(index) * bucketSeconds)
            let end = min(start.addingTimeInterval(bucketSeconds), range.end)
            return ProviderIntradayUsagePoint(
                start: start,
                end: end,
                totalTokens: item.total,
                inputTokens: item.input,
                outputTokens: item.output,
                cacheReadTokens: item.cached
            )
        }

        return ProviderIntradayUsageSnapshot(
            dayKey: dayKey,
            timezoneIdentifier: timezone.identifier,
            bucket: bucket,
            actualBucketCount: actualBucketCount,
            rangeStart: range.start,
            rangeEnd: range.end,
            points: points,
            fetchedAt: now(),
            sourceLabel: "session"
        )
    }

    private static func emptySnapshot(
        dayKey: String,
        bucket: ProviderIntradayBucket,
        timezone: TimeZone,
        rangeStart: Date,
        rangeEnd: Date,
        fetchedAt: Date
    ) -> ProviderIntradayUsageSnapshot {
        let bucketSeconds = Self.bucketSeconds(for: bucket)
        let actualBucketCount = Int((rangeEnd.timeIntervalSince(rangeStart) / bucketSeconds).rounded())
        let points = (0..<actualBucketCount).map { index in
            let start = rangeStart.addingTimeInterval(Double(index) * bucketSeconds)
            let end = min(start.addingTimeInterval(bucketSeconds), rangeEnd)
            return ProviderIntradayUsagePoint(
                start: start,
                end: end,
                totalTokens: 0,
                inputTokens: 0,
                outputTokens: 0,
                cacheReadTokens: 0
            )
        }
        return ProviderIntradayUsageSnapshot(
            dayKey: dayKey,
            timezoneIdentifier: timezone.identifier,
            bucket: bucket,
            actualBucketCount: actualBucketCount,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            points: points,
            fetchedAt: fetchedAt,
            sourceLabel: "session"
        )
    }

    private static func bucketSeconds(for bucket: ProviderIntradayBucket) -> TimeInterval {
        switch bucket {
        case .minute15:
            return 15 * 60
        case .minute30:
            return 30 * 60
        case .hour1:
            return 60 * 60
        }
    }

    private static func makeDayRange(dayKey: String, timezone: TimeZone) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar(timezone: timezone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: dayKey) else { return nil }
        guard let end = formatter.calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    private static func parseISODate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            return fallback.date(from: text)
        }()
    }

    private static func calendar(timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
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

private struct GeminiIntradayConversationRecord: Decodable {
    let messages: [GeminiIntradayConversationMessage]
}

private struct GeminiIntradayConversationMessage: Decodable {
    let type: String
    let timestamp: String
    let tokens: GeminiIntradayConversationTokens?
}

private struct GeminiIntradayConversationTokens: Decodable {
    let input: Int
    let output: Int
    let cached: Int
    let total: Int
}

private struct GeminiIntradayBucketTotals {
    var input = 0
    var output = 0
    var cached = 0
    var total = 0
}
