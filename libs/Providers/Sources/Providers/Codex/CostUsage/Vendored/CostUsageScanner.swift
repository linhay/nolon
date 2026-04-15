import Foundation
import CodexCLIKit
import CodexBarProviderCatalog
import ProvidersShared
import STFilePath

enum CostUsageScanner {
    struct Options: Sendable {
        var codexSessionsRoot: STFolder?
        var cacheRoot: STFolder?
        var refreshMinIntervalSeconds: TimeInterval = 60
        // Force a full rescan, ignoring per-file cache and incremental offsets.
        var forceRescan: Bool = false

        init(
            codexSessionsRoot: STFolder? = nil,
            cacheRoot: STFolder? = nil,
            forceRescan: Bool = false)
        {
            self.codexSessionsRoot = codexSessionsRoot
            self.cacheRoot = cacheRoot
            self.forceRescan = forceRescan
        }

        init(
            codexSessionsRootURL: URL?,
            cacheRootURL: URL?,
            forceRescan: Bool = false)
        {
            self.init(
                codexSessionsRoot: codexSessionsRootURL.map(STFolder.init),
                cacheRoot: cacheRootURL.map(STFolder.init),
                forceRescan: forceRescan
            )
        }
    }

    struct CodexParseResult: Sendable {
        let days: [String: [String: [Int]]]
        let quarterHours: [String: [String: [Int]]]
        let parsedBytes: Int64
        let lastModel: String?
        let lastTotals: CostUsageCodexTotals?
        let sessionId: String?
    }

    private struct CodexScanState {
        var seenSessionIds: Set<String> = []
        var seenFileIds: Set<String> = []
    }

    static func loadDailyReport(
        provider: UsageProvider,
        since: Date,
        until: Date,
        now: Date = Date(),
        options: Options = Options()) -> CostUsageDailyReport
    {
        let range = CostUsageDayRange(since: since, until: until)

        switch provider {
        case .codex:
            return self.loadCodexDaily(range: range, now: now, options: options)
        default:
            return CostUsageDailyReport(data: [], summary: nil)
        }
    }

    // MARK: - Day keys

    struct CostUsageDayRange: Sendable {
        let sinceKey: String
        let untilKey: String
        let scanSinceKey: String
        let scanUntilKey: String

        init(since: Date, until: Date) {
            self.sinceKey = Self.dayKey(from: since)
            self.untilKey = Self.dayKey(from: until)
            self.scanSinceKey = Self.dayKey(from: Calendar.current.date(byAdding: .day, value: -1, to: since) ?? since)
            self.scanUntilKey = Self.dayKey(from: Calendar.current.date(byAdding: .day, value: 1, to: until) ?? until)
        }

        static func dayKey(from date: Date) -> String {
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            let y = comps.year ?? 1970
            let m = comps.month ?? 1
            let d = comps.day ?? 1
            return String(format: "%04d-%02d-%02d", y, m, d)
        }

        static func isInRange(dayKey: String, since: String, until: String) -> Bool {
            if dayKey < since { return false }
            if dayKey > until { return false }
            return true
        }
    }

    // MARK: - Codex

    private static func defaultCodexSessionsRoot(options: Options) -> STFolder {
        if let override = options.codexSessionsRoot { return override }
        return STFolder(CodexCommandExecutor.codexHomeDirectoryURL())
            .folder("sessions")
    }

    static func parseCodexFile(
        file: STFile,
        range: CostUsageDayRange,
        startOffset: Int64 = 0,
        initialModel: String? = nil,
        initialTotals: CostUsageCodexTotals? = nil) -> CodexParseResult
    {
        parseCodexFile(
            fileURL: file.url,
            range: range,
            startOffset: startOffset,
            initialModel: initialModel,
            initialTotals: initialTotals
        )
    }

    static func parseCodexFile(
        fileURL: URL,
        range: CostUsageDayRange,
        startOffset: Int64 = 0,
        initialModel: String? = nil,
        initialTotals: CostUsageCodexTotals? = nil) -> CodexParseResult
    {
        var currentModel = initialModel
        var previousTotals = initialTotals
        var sessionId: String?

        var days: [String: [String: [Int]]] = [:]
        var quarterHours: [String: [String: [Int]]] = [:]

        func add(dayKey: String, model: String, input: Int, cached: Int, output: Int) {
            guard CostUsageDayRange.isInRange(dayKey: dayKey, since: range.scanSinceKey, until: range.scanUntilKey)
            else { return }
            let normModel = CostUsagePricing.normalizeCodexModel(model)

            var dayModels = days[dayKey] ?? [:]
            var packed = dayModels[normModel] ?? [0, 0, 0]
            packed[0] = (packed[safe: 0] ?? 0) + input
            packed[1] = (packed[safe: 1] ?? 0) + cached
            packed[2] = (packed[safe: 2] ?? 0) + output
            dayModels[normModel] = packed
            days[dayKey] = dayModels
        }

        func addQuarterHour(dayKey: String, bucketKey: String, input: Int, cached: Int, output: Int) {
            guard CostUsageDayRange.isInRange(dayKey: dayKey, since: range.scanSinceKey, until: range.scanUntilKey)
            else { return }

            var dayBuckets = quarterHours[dayKey] ?? [:]
            var packed = dayBuckets[bucketKey] ?? [0, 0, 0]
            packed[0] = (packed[safe: 0] ?? 0) + input
            packed[1] = (packed[safe: 1] ?? 0) + cached
            packed[2] = (packed[safe: 2] ?? 0) + output
            dayBuckets[bucketKey] = packed
            quarterHours[dayKey] = dayBuckets
        }

        let maxLineBytes = 256 * 1024
        let prefixBytes = 32 * 1024

        let parsedBytes = (try? CostUsageJsonl.scan(
            fileURL: fileURL,
            offset: startOffset,
            maxLineBytes: maxLineBytes,
            prefixBytes: prefixBytes,
            onLine: { line in
                guard !line.bytes.isEmpty else { return }
                guard !line.wasTruncated else { return }
                let parserTotals = previousTotals.map {
                    CodexSessionTokenTotals(
                        inputTokens: $0.input,
                        cachedInputTokens: $0.cached,
                        outputTokens: $0.output)
                }

                guard let reduced = CodexSessionEventParser.reduceUsageLine(
                    data: line.bytes,
                    currentModel: currentModel,
                    previousTotals: parserTotals)
                else { return }

                if sessionId == nil {
                    sessionId = reduced.sessionID
                }
                currentModel = reduced.updatedModel

                if let totals = reduced.updatedTotals {
                    previousTotals = CostUsageCodexTotals(
                        input: totals.inputTokens,
                        cached: totals.cachedInputTokens,
                        output: totals.outputTokens)
                }

                guard let delta = reduced.tokenDelta else { return }
                guard let tsText = delta.timestamp else { return }
                guard let dayKey = Self.dayKeyFromTimestamp(tsText) ?? Self.dayKeyFromParsedISO(tsText) else { return }
                add(
                    dayKey: dayKey,
                    model: delta.model,
                    input: delta.inputTokens,
                    cached: delta.cachedInputTokens,
                    output: delta.outputTokens)
                if let bucketKey = Self.quarterHourKeyFromParsedISO(tsText) {
                    addQuarterHour(
                        dayKey: dayKey,
                        bucketKey: bucketKey,
                        input: delta.inputTokens,
                        cached: delta.cachedInputTokens,
                        output: delta.outputTokens
                    )
                }
            })) ?? startOffset

        return CodexParseResult(
            days: days,
            quarterHours: quarterHours,
            parsedBytes: parsedBytes,
            lastModel: currentModel,
            lastTotals: previousTotals,
            sessionId: sessionId)
    }

    private static func scanCodexFile(
        file: STFile,
        fileIdentity: String?,
        range: CostUsageDayRange,
        cache: inout CostUsageCache,
        state: inout CodexScanState)
    {
        let path = file.path
        let mtime = file.attributes.modificationDate.timeIntervalSince1970
        let size = Int64(file.attributes.size)
        let mtimeMs = Int64(mtime * 1000)
        let fileId = fileIdentity

        func dropCachedFile(_ cached: CostUsageFileUsage?) {
            if let cached {
                Self.applyFileDays(cache: &cache, fileDays: cached.days, sign: -1)
                Self.applyFileQuarterHours(cache: &cache, fileQuarterHours: cached.quarterHours, sign: -1)
            }
            cache.files.removeValue(forKey: path)
        }

        if let fileId, state.seenFileIds.contains(fileId) {
            dropCachedFile(cache.files[path])
            return
        }

        let cached = cache.files[path]
        if let cachedSessionId = cached?.sessionId, state.seenSessionIds.contains(cachedSessionId) {
            dropCachedFile(cached)
            return
        }

        let needsSessionId = cached != nil && cached?.sessionId == nil
        if let cached,
           cached.mtimeUnixMs == mtimeMs,
           cached.size == size,
           !needsSessionId
        {
            if let cachedSessionId = cached.sessionId {
                state.seenSessionIds.insert(cachedSessionId)
            }
            if let fileId {
                state.seenFileIds.insert(fileId)
            }
            return
        }

        if let cached, cached.sessionId != nil {
            let startOffset = cached.parsedBytes ?? cached.size
            let canIncremental = size > cached.size && startOffset > 0 && startOffset <= size
                && cached.lastTotals != nil
            if canIncremental {
                let delta = Self.parseCodexFile(
                    file: file,
                    range: range,
                    startOffset: startOffset,
                    initialModel: cached.lastModel,
                    initialTotals: cached.lastTotals)
                let sessionId = delta.sessionId ?? cached.sessionId
                if let sessionId, state.seenSessionIds.contains(sessionId) {
                    dropCachedFile(cached)
                    return
                }

                if !delta.days.isEmpty {
                    Self.applyFileDays(cache: &cache, fileDays: delta.days, sign: 1)
                }
                if !delta.quarterHours.isEmpty {
                    Self.applyFileQuarterHours(cache: &cache, fileQuarterHours: delta.quarterHours, sign: 1)
                }

                var mergedDays = cached.days
                Self.mergeFileDays(existing: &mergedDays, delta: delta.days)
                var mergedQuarterHours = cached.quarterHours
                Self.mergeFileQuarterHours(existing: &mergedQuarterHours, delta: delta.quarterHours)
                cache.files[path] = Self.makeFileUsage(
                    mtimeUnixMs: mtimeMs,
                    size: size,
                    days: mergedDays,
                    quarterHours: mergedQuarterHours,
                    parsedBytes: delta.parsedBytes,
                    lastModel: delta.lastModel,
                    lastTotals: delta.lastTotals,
                    sessionId: sessionId)
                if let sessionId {
                    state.seenSessionIds.insert(sessionId)
                }
                if let fileId {
                    state.seenFileIds.insert(fileId)
                }
                return
            }
        }

        if let cached {
            Self.applyFileDays(cache: &cache, fileDays: cached.days, sign: -1)
        }

        let parsed = Self.parseCodexFile(file: file, range: range)
        let sessionId = parsed.sessionId ?? cached?.sessionId
        if let sessionId, state.seenSessionIds.contains(sessionId) {
            cache.files.removeValue(forKey: path)
            return
        }

        let usage = Self.makeFileUsage(
            mtimeUnixMs: mtimeMs,
            size: size,
            days: parsed.days,
            quarterHours: parsed.quarterHours,
            parsedBytes: parsed.parsedBytes,
            lastModel: parsed.lastModel,
            lastTotals: parsed.lastTotals,
            sessionId: sessionId)
        cache.files[path] = usage
        Self.applyFileDays(cache: &cache, fileDays: usage.days, sign: 1)
        Self.applyFileQuarterHours(cache: &cache, fileQuarterHours: usage.quarterHours, sign: 1)
        if let sessionId {
            state.seenSessionIds.insert(sessionId)
        }
        if let fileId {
            state.seenFileIds.insert(fileId)
        }
    }

    private static func loadCodexDaily(range: CostUsageDayRange, now: Date, options: Options) -> CostUsageDailyReport {
        var cache = CostUsageCacheIO.load(provider: .codex, cacheRoot: options.cacheRoot)
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)

        let refreshMs = Int64(max(0, options.refreshMinIntervalSeconds) * 1000)
        let shouldRefresh = refreshMs == 0
            || cache.lastScanUnixMs == 0
            || nowMs - cache.lastScanUnixMs > refreshMs
            || cacheNeedsExpandedCoverage(cache: cache, range: range)

        let scannedFiles = CodexSessionScanner.scanFiles(
            sessionsRoot: defaultCodexSessionsRoot(options: options),
            includeArchivedSibling: true,
            dayRange: .init(sinceKey: range.scanSinceKey, untilKey: range.scanUntilKey)
        )
        let filePathsInScan = Set(scannedFiles.map { $0.file.path })

        if shouldRefresh {
            if options.forceRescan {
                cache = CostUsageCache()
            }
            var scanState = CodexScanState()
            for scannedFile in scannedFiles {
                Self.scanCodexFile(
                    file: scannedFile.file,
                    fileIdentity: scannedFile.fileIdentity,
                    range: range,
                    cache: &cache,
                    state: &scanState)
            }

            for key in cache.files.keys where !filePathsInScan.contains(key) {
                if let old = cache.files[key] {
                    Self.applyFileDays(cache: &cache, fileDays: old.days, sign: -1)
                    Self.applyFileQuarterHours(cache: &cache, fileQuarterHours: old.quarterHours, sign: -1)
                }
                cache.files.removeValue(forKey: key)
            }

            // Keep historical day aggregates in cache across narrower scans.
            // Range filtering happens when building the report, otherwise a prior 30d read
            // can permanently hide older history from a later all-time read until a full rescan.
            cache.lastScanUnixMs = nowMs
            CostUsageCacheIO.save(provider: .codex, cache: cache, cacheRoot: options.cacheRoot)
        }

        return Self.buildCodexReportFromCache(cache: cache, range: range)
    }

    private static func buildCodexReportFromCache(
        cache: CostUsageCache,
        range: CostUsageDayRange) -> CostUsageDailyReport
    {
        var entries: [CostUsageDailyReport.Entry] = []
        var totalInput = 0
        var totalOutput = 0
        var totalCached = 0
        var totalTokens = 0
        var totalCost: Double = 0
        var costSeen = false

        let dayKeys = cache.days.keys.sorted().filter {
            CostUsageDayRange.isInRange(dayKey: $0, since: range.sinceKey, until: range.untilKey)
        }

        for day in dayKeys {
            guard let models = cache.days[day] else { continue }
            let modelNames = models.keys.sorted()

            var dayInput = 0
            var dayOutput = 0
            var dayCached = 0

            var breakdown: [CostUsageDailyReport.ModelBreakdown] = []
            var dayCost: Double = 0
            var dayCostSeen = false

            for model in modelNames {
                let packed = models[model] ?? [0, 0, 0]
                let input = packed[safe: 0] ?? 0
                let cached = packed[safe: 1] ?? 0
                let output = packed[safe: 2] ?? 0

                dayInput += input
                dayOutput += output
                dayCached += cached

                let cost = CostUsagePricing.codexCostUSD(
                    model: model,
                    inputTokens: input,
                    cachedInputTokens: cached,
                    outputTokens: output)
                breakdown.append(CostUsageDailyReport.ModelBreakdown(modelName: model, costUSD: cost))
                if let cost {
                    dayCost += cost
                    dayCostSeen = true
                }
            }

            breakdown.sort { lhs, rhs in (rhs.costUSD ?? -1) < (lhs.costUSD ?? -1) }
            let top = Array(breakdown.prefix(3))

            let dayTotal = dayInput + dayOutput
            let entryCost = dayCostSeen ? dayCost : nil
            entries.append(CostUsageDailyReport.Entry(
                date: day,
                inputTokens: dayInput,
                outputTokens: dayOutput,
                cacheReadTokens: dayCached,
                totalTokens: dayTotal,
                costUSD: entryCost,
                modelsUsed: modelNames,
                modelBreakdowns: top))

            totalInput += dayInput
            totalOutput += dayOutput
            totalCached += dayCached
            totalTokens += dayTotal
            if let entryCost {
                totalCost += entryCost
                costSeen = true
            }
        }

        let summary: CostUsageDailyReport.Summary? = entries.isEmpty
            ? nil
            : CostUsageDailyReport.Summary(
                totalInputTokens: totalInput,
                totalOutputTokens: totalOutput,
                cacheReadTokens: totalCached,
                totalTokens: totalTokens,
                totalCostUSD: costSeen ? totalCost : nil)

        return CostUsageDailyReport(data: entries, summary: summary)
    }

    private static func cacheNeedsExpandedCoverage(cache: CostUsageCache, range: CostUsageDayRange) -> Bool {
        guard !cache.days.isEmpty else { return false }
        let cachedDayKeys = cache.days.keys.sorted()
        guard let earliest = cachedDayKeys.first, let latest = cachedDayKeys.last else { return false }
        if range.scanSinceKey < earliest {
            return true
        }
        if range.scanUntilKey > latest {
            return true
        }
        return false
    }

    // MARK: - Shared cache mutations

    static func makeFileUsage(
        mtimeUnixMs: Int64,
        size: Int64,
        days: [String: [String: [Int]]],
        quarterHours: [String: [String: [Int]]],
        parsedBytes: Int64?,
        lastModel: String? = nil,
        lastTotals: CostUsageCodexTotals? = nil,
        sessionId: String? = nil) -> CostUsageFileUsage
    {
        CostUsageFileUsage(
            mtimeUnixMs: mtimeUnixMs,
            size: size,
            days: days,
            quarterHours: quarterHours,
            parsedBytes: parsedBytes,
            lastModel: lastModel,
            lastTotals: lastTotals,
            sessionId: sessionId)
    }

    static func mergeFileDays(
        existing: inout [String: [String: [Int]]],
        delta: [String: [String: [Int]]])
    {
        for (day, models) in delta {
            var dayModels = existing[day] ?? [:]
            for (model, packed) in models {
                let existingPacked = dayModels[model] ?? []
                let merged = Self.addPacked(a: existingPacked, b: packed, sign: 1)
                if merged.allSatisfy({ $0 == 0 }) {
                    dayModels.removeValue(forKey: model)
                } else {
                    dayModels[model] = merged
                }
            }

            if dayModels.isEmpty {
                existing.removeValue(forKey: day)
            } else {
                existing[day] = dayModels
            }
        }
    }

    static func applyFileDays(cache: inout CostUsageCache, fileDays: [String: [String: [Int]]], sign: Int) {
        for (day, models) in fileDays {
            var dayModels = cache.days[day] ?? [:]
            for (model, packed) in models {
                let existing = dayModels[model] ?? []
                let merged = Self.addPacked(a: existing, b: packed, sign: sign)
                if merged.allSatisfy({ $0 == 0 }) {
                    dayModels.removeValue(forKey: model)
                } else {
                    dayModels[model] = merged
                }
            }

            if dayModels.isEmpty {
                cache.days.removeValue(forKey: day)
            } else {
                cache.days[day] = dayModels
            }
        }
    }

    static func mergeFileQuarterHours(
        existing: inout [String: [String: [Int]]],
        delta: [String: [String: [Int]]]
    ) {
        for (day, buckets) in delta {
            var dayBuckets = existing[day] ?? [:]
            for (bucketKey, packed) in buckets {
                let existingPacked = dayBuckets[bucketKey] ?? []
                let merged = Self.addPacked(a: existingPacked, b: packed, sign: 1)
                if merged.allSatisfy({ $0 == 0 }) {
                    dayBuckets.removeValue(forKey: bucketKey)
                } else {
                    dayBuckets[bucketKey] = merged
                }
            }

            if dayBuckets.isEmpty {
                existing.removeValue(forKey: day)
            } else {
                existing[day] = dayBuckets
            }
        }
    }

    static func applyFileQuarterHours(
        cache: inout CostUsageCache,
        fileQuarterHours: [String: [String: [Int]]],
        sign: Int
    ) {
        for (day, buckets) in fileQuarterHours {
            var dayBuckets = cache.quarterHours[day] ?? [:]
            for (bucketKey, packed) in buckets {
                let existing = dayBuckets[bucketKey] ?? []
                let merged = Self.addPacked(a: existing, b: packed, sign: sign)
                if merged.allSatisfy({ $0 == 0 }) {
                    dayBuckets.removeValue(forKey: bucketKey)
                } else {
                    dayBuckets[bucketKey] = merged
                }
            }

            if dayBuckets.isEmpty {
                cache.quarterHours.removeValue(forKey: day)
            } else {
                cache.quarterHours[day] = dayBuckets
            }
        }
    }

    static func pruneDays(cache: inout CostUsageCache, sinceKey: String, untilKey: String) {
        for key in cache.days.keys where !CostUsageDayRange.isInRange(dayKey: key, since: sinceKey, until: untilKey) {
            cache.days.removeValue(forKey: key)
        }
        for key in cache.quarterHours.keys where !CostUsageDayRange.isInRange(dayKey: key, since: sinceKey, until: untilKey) {
            cache.quarterHours.removeValue(forKey: key)
        }
    }

    static func addPacked(a: [Int], b: [Int], sign: Int) -> [Int] {
        let len = max(a.count, b.count)
        var out: [Int] = Array(repeating: 0, count: len)
        for idx in 0..<len {
            let next = (a[safe: idx] ?? 0) + sign * (b[safe: idx] ?? 0)
            out[idx] = max(0, next)
        }
        return out
    }

    // MARK: - Date parsing

    private static func parseDayKey(_ key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3 else { return nil }
        guard
            let y = Int(parts[0]),
            let m = Int(parts[1]),
            let d = Int(parts[2])
        else { return nil }

        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone.current
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = 12
        return comps.date
    }
}

extension Data {
    func containsAscii(_ needle: String) -> Bool {
        guard let n = needle.data(using: .utf8) else { return false }
        return self.range(of: n) != nil
    }
}

extension [Int] {
    subscript(safe index: Int) -> Int? {
        if index < 0 { return nil }
        if index >= self.count { return nil }
        return self[index]
    }
}

extension [UInt8] {
    subscript(safe index: Int) -> UInt8? {
        if index < 0 { return nil }
        if index >= self.count { return nil }
        return self[index]
    }
}
