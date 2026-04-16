import Foundation
import CodexBarProviderCatalog

public struct GeminiTokenTrendService: Sendable {
    typealias LoadActiveAccount = @Sendable (UsageProvider) async throws -> GeminiAuthAccount?
    typealias LoadSessionRoot = @Sendable () -> URL?
    typealias ListSessionFiles = @Sendable (URL) throws -> [URL]
    typealias ReadFile = @Sendable (URL) throws -> String
    typealias LoadFileFingerprint = @Sendable (URL) -> GeminiSessionFileFingerprint

    private let loadActiveAccount: LoadActiveAccount
    private let loadSessionRoot: LoadSessionRoot
    private let listSessionFiles: ListSessionFiles
    private let readFile: ReadFile
    private let loadFileFingerprint: LoadFileFingerprint
    private let usageStore: GeminiSessionUsageStore
    private let now: @Sendable () -> Date

    public init() {
        let store = GeminiAuthStore.shared
        self.loadActiveAccount = { provider in
            try await store.activeAccount(provider: provider)
        }
        self.loadSessionRoot = GeminiSessionUsageSupport.defaultSessionRoot
        self.listSessionFiles = GeminiSessionUsageSupport.defaultListSessionFiles
        self.readFile = { url in
            try String(contentsOf: url, encoding: .utf8)
        }
        self.loadFileFingerprint = GeminiSessionUsageStore.defaultLoadFileFingerprint
        self.usageStore = .shared
        self.now = Date.init
    }

    init(
        loadActiveAccount: @escaping LoadActiveAccount,
        loadSessionRoot: @escaping LoadSessionRoot = { nil },
        listSessionFiles: @escaping ListSessionFiles,
        readFile: @escaping ReadFile,
        loadFileFingerprint: @escaping LoadFileFingerprint = GeminiSessionUsageStore.defaultLoadFileFingerprint,
        usageStore: GeminiSessionUsageStore = GeminiSessionUsageStore(cacheFileURL: nil),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loadActiveAccount = loadActiveAccount
        self.loadSessionRoot = loadSessionRoot
        self.listSessionFiles = listSessionFiles
        self.readFile = readFile
        self.loadFileFingerprint = loadFileFingerprint
        self.usageStore = usageStore
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
                allDaysTokens: nil,
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
                allDaysTokens: nil,
                updatedAt: now(),
                sourceLabel: "session"
            )
        }

        let usageSnapshot = try await usageStore.loadSnapshot(
            sessionFiles: sessionFiles,
            readFile: readFile,
            loadFileFingerprint: loadFileFingerprint
        )

        let allPoints = usageSnapshot.daily.keys.sorted().map { day in
            let totals = usageSnapshot.daily[day, default: GeminiCachedDayTotals()]
            return ProviderTokenTrendPoint(
                date: day,
                totalTokens: totals.total,
                inputTokens: totals.input,
                outputTokens: totals.output,
                cacheReadTokens: totals.cached
            )
        }

        let points: [ProviderTokenTrendPoint]
        if let trailingDays, trailingDays > 0, allPoints.count > trailingDays {
            points = Array(allPoints.suffix(trailingDays))
        } else {
            points = allPoints
        }

        let today = todayTokens(from: allPoints, now: now())
        let last7 = sumTrailing(points: allPoints, days: 7)
        let last30 = sumTrailing(points: allPoints, days: 30)
        let all = sumAll(points: allPoints)
        return ProviderTokenTrendSnapshot(
            points: points,
            todayTokens: today,
            last7DaysTokens: last7,
            last30DaysTokens: last30,
            allDaysTokens: all,
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

    private func sumAll(points: [ProviderTokenTrendPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        return points.map(\.totalTokens).reduce(0, +)
    }

    private func todayTokens(from points: [ProviderTokenTrendPoint], now: Date) -> Int {
        let todayKey = Self.dayKey(from: now)
        return points.first(where: { $0.date == todayKey })?.totalTokens ?? 0
    }

    private static func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct GeminiSessionFileFingerprint: Codable, Sendable, Equatable {
    let mtimeUnixMs: Int64
    let size: Int64
}

struct GeminiCachedTokenEvent: Codable, Sendable, Equatable {
    let timestamp: Date
    let input: Int
    let output: Int
    let cached: Int
    let total: Int
}

struct GeminiCachedDayTotals: Codable, Sendable, Equatable {
    var input: Int
    var output: Int
    var cached: Int
    var total: Int

    init(input: Int = 0, output: Int = 0, cached: Int = 0, total: Int = 0) {
        self.input = input
        self.output = output
        self.cached = cached
        self.total = total
    }

    mutating func add(input: Int, output: Int, cached: Int, total: Int) {
        self.input += input
        self.output += output
        self.cached += cached
        self.total += total
    }
}

private struct GeminiSessionUsageFileCache: Codable, Sendable, Equatable {
    let fingerprint: GeminiSessionFileFingerprint
    let daily: [String: GeminiCachedDayTotals]
    let events: [GeminiCachedTokenEvent]
}

private struct GeminiSessionUsageCache: Codable, Sendable, Equatable {
    var version: Int = 1
    var files: [String: GeminiSessionUsageFileCache] = [:]
}

private struct GeminiParsedSessionUsage: Sendable, Equatable {
    let daily: [String: GeminiCachedDayTotals]
    let events: [GeminiCachedTokenEvent]
}

actor GeminiSessionUsageStore {
    struct Snapshot: Sendable, Equatable {
        let daily: [String: GeminiCachedDayTotals]
        let events: [GeminiCachedTokenEvent]
    }

    private struct ResolvedFileState: Equatable {
        let url: URL
        let path: String
        let fingerprint: GeminiSessionFileFingerprint
    }

    private struct SnapshotCacheEntry: Equatable {
        let files: [ResolvedFileState]
        let snapshot: Snapshot
    }

    static let shared = GeminiSessionUsageStore(cacheFileURL: GeminiSessionUsageStore.defaultCacheFileURL())

    private let cacheFileURL: URL?
    private var cache: GeminiSessionUsageCache?
    private var lastSnapshotCache: SnapshotCacheEntry?
#if DEBUG
    private var snapshotCacheHitCount = 0
    private var snapshotCacheMissCount = 0
#endif

    init(cacheFileURL: URL? = nil) {
        self.cacheFileURL = cacheFileURL
    }

    func loadSnapshot(
        sessionFiles: [URL],
        readFile: @Sendable (URL) throws -> String,
        loadFileFingerprint: @Sendable (URL) -> GeminiSessionFileFingerprint
    ) async throws -> Snapshot {
        let resolvedFiles = Array(Set(sessionFiles.map { $0.standardizedFileURL }))
            .sorted { $0.path < $1.path }
            .map { url in
                let path = url.path
                let fingerprint = loadFileFingerprint(url)
                return ResolvedFileState(url: url, path: path, fingerprint: fingerprint)
            }

        if let lastSnapshotCache, lastSnapshotCache.files == resolvedFiles {
#if DEBUG
            snapshotCacheHitCount += 1
#endif
            return lastSnapshotCache.snapshot
        }
#if DEBUG
        snapshotCacheMissCount += 1
#endif

        var workingCache = cache ?? Self.loadCache(from: cacheFileURL)
        var didMutateCache = false

        let livePaths = Set(resolvedFiles.map(\.path))

        for stalePath in workingCache.files.keys where !livePaths.contains(stalePath) {
            workingCache.files.removeValue(forKey: stalePath)
            didMutateCache = true
        }

        var mergedDaily: [String: GeminiCachedDayTotals] = [:]
        var mergedEvents: [GeminiCachedTokenEvent] = []

        for resolvedFile in resolvedFiles {
            let fileCache: GeminiSessionUsageFileCache
            if let cachedFile = workingCache.files[resolvedFile.path],
               cachedFile.fingerprint == resolvedFile.fingerprint {
                fileCache = cachedFile
            } else {
                let raw = try readFile(resolvedFile.url)
                let parsed = try Self.parseSessionFile(raw)
                fileCache = GeminiSessionUsageFileCache(
                    fingerprint: resolvedFile.fingerprint,
                    daily: parsed.daily,
                    events: parsed.events
                )
                workingCache.files[resolvedFile.path] = fileCache
                didMutateCache = true
            }

            Self.mergeDaily(from: fileCache.daily, into: &mergedDaily)
            mergedEvents.append(contentsOf: fileCache.events)
        }

        mergedEvents.sort { $0.timestamp < $1.timestamp }

        if didMutateCache {
            Self.saveCache(workingCache, to: cacheFileURL)
        }
        cache = workingCache
        let snapshot = Snapshot(daily: mergedDaily, events: mergedEvents)
        lastSnapshotCache = SnapshotCacheEntry(files: resolvedFiles, snapshot: snapshot)

        return snapshot
    }

#if DEBUG
    func snapshotCacheStatsForTesting() -> (hits: Int, misses: Int) {
        (snapshotCacheHitCount, snapshotCacheMissCount)
    }
#endif

    nonisolated static func defaultLoadFileFingerprint(_ url: URL) -> GeminiSessionFileFingerprint {
        let standardizedURL = url.standardizedFileURL
        let values = try? standardizedURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let mtimeUnixMs = Int64((values?.contentModificationDate ?? Date(timeIntervalSince1970: 0)).timeIntervalSince1970 * 1000)
        let size = Int64(values?.fileSize ?? 0)
        return GeminiSessionFileFingerprint(mtimeUnixMs: mtimeUnixMs, size: size)
    }

    private nonisolated static func defaultCacheFileURL() -> URL {
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Caches", isDirectory: true)
        return cacheRoot
            .appendingPathComponent("CodexBar", isDirectory: true)
            .appendingPathComponent("provider-usage", isDirectory: true)
            .appendingPathComponent("gemini-session-usage-v1.json", isDirectory: false)
    }

    private nonisolated static func loadCache(from url: URL?) -> GeminiSessionUsageCache {
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(GeminiSessionUsageCache.self, from: data),
              decoded.version == 1 else {
            return GeminiSessionUsageCache()
        }
        return decoded
    }

    private nonisolated static func saveCache(_ cache: GeminiSessionUsageCache, to url: URL?) {
        guard let url else { return }
        let directoryURL = url.deletingLastPathComponent()
        let tmpURL = directoryURL.appendingPathComponent(".tmp-\(UUID().uuidString).json")
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(cache)
            try data.write(to: tmpURL, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tmpURL, to: url)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }

    private nonisolated static func parseSessionFile(_ raw: String) throws -> GeminiParsedSessionUsage {
        let record = try JSONDecoder().decode(GeminiSessionUsageRecord.self, from: Data(raw.utf8))

        var daily: [String: GeminiCachedDayTotals] = [:]
        var events: [GeminiCachedTokenEvent] = []

        for message in record.messages where message.type == "gemini" {
            guard let tokens = message.tokens else { continue }

            if let dayKey = dayString(from: message.timestamp) {
                var totals = daily[dayKey, default: GeminiCachedDayTotals()]
                totals.add(
                    input: max(0, tokens.input),
                    output: max(0, tokens.output),
                    cached: max(0, tokens.cached),
                    total: max(0, tokens.total)
                )
                daily[dayKey] = totals
            }

            guard let timestamp = parseISODate(message.timestamp) else { continue }
            events.append(
                GeminiCachedTokenEvent(
                    timestamp: timestamp,
                    input: max(0, tokens.input),
                    output: max(0, tokens.output),
                    cached: max(0, tokens.cached),
                    total: max(0, tokens.total)
                )
            )
        }

        return GeminiParsedSessionUsage(daily: daily, events: events)
    }

    private nonisolated static func mergeDaily(
        from source: [String: GeminiCachedDayTotals],
        into destination: inout [String: GeminiCachedDayTotals]
    ) {
        for (dayKey, totals) in source {
            var merged = destination[dayKey, default: GeminiCachedDayTotals()]
            merged.add(
                input: totals.input,
                output: totals.output,
                cached: totals.cached,
                total: totals.total
            )
            destination[dayKey] = merged
        }
    }

    private nonisolated static func dayString(from timestamp: String) -> String? {
        let trimmed = timestamp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return nil }
        let prefix = String(trimmed.prefix(10))
        return prefix.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil ? prefix : nil
    }

    private nonisolated static func parseISODate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: text)
    }
}

private struct GeminiSessionUsageRecord: Decodable {
    let messages: [GeminiSessionUsageMessage]
}

private struct GeminiSessionUsageMessage: Decodable {
    let type: String
    let timestamp: String
    let tokens: GeminiSessionUsageTokens?
}

private struct GeminiSessionUsageTokens: Decodable {
    let input: Int
    let output: Int
    let cached: Int
    let total: Int
}
