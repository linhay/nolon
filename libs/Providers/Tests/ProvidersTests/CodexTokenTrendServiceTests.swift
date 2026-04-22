import Foundation
import Testing
import STFilePath
@testable import ProviderUsage
@testable import CodexProvider

@Suite("Codex Token Trend Service")
struct CodexTokenTrendServiceTests {
    @Test("maps daily token entries and computes rolling summaries")
    func mapsDailyEntriesAndSummaries() async throws {
        let now = Self.makeLocalDate(year: 2026, month: 2, day: 26, hour: 12, minute: 0)
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 120,
            sessionCostUSD: nil,
            todayInputTokens: 60,
            todayOutputTokens: 40,
            todayCachedInputTokens: 20,
            rangeDays: 30,
            rangeTokens: 1_000,
            rangeCostUSD: nil,
            rangeInputTokens: 500,
            rangeOutputTokens: 350,
            rangeCachedInputTokens: 150,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2026-02-24",
                    inputTokens: 100,
                    outputTokens: 80,
                    cacheReadTokens: 20,
                    totalTokens: 180,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
                CostUsageDailyReport.Entry(
                    date: "2026-02-25",
                    inputTokens: 120,
                    outputTokens: 90,
                    cacheReadTokens: 30,
                    totalTokens: 210,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
                CostUsageDailyReport.Entry(
                    date: "2026-02-26",
                    inputTokens: 60,
                    outputTokens: 40,
                    cacheReadTokens: 20,
                    totalTokens: 120,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
            ],
            updatedAt: now,
            source: .scopedSessions
        )

        let service = Self.makeService { _, _, _, _ in snapshot }
        let result = try await service.fetchGlobalSnapshot(trailingDays: 30, environment: ["CODEX_HOME": "/tmp/account-home"])

        #expect(result.points.count == 3)
        #expect(result.points[0].date == "2026-02-24")
        #expect(result.points[0].totalTokens == 180)
        #expect(result.points[0].inputTokens == 100)
        #expect(result.points[0].outputTokens == 80)
        #expect(result.points[0].cacheReadTokens == 20)
        #expect(result.todayTokens == 120)
        #expect(result.last7DaysTokens == 510)
        #expect(result.last30DaysTokens == 510)
        #expect(result.allDaysTokens == 510)
        #expect(result.sourceLabel == "global local usage")
    }

    @Test("keeps summary metrics stable while slicing chart range")
    func keepsSummaryMetricsStableWhileSlicingChartRange() async throws {
        let now = Self.makeLocalDate(year: 2026, month: 2, day: 28, hour: 12, minute: 0)
        let entries = (1...40).map { index in
            CostUsageDailyReport.Entry(
                date: String(format: "2026-02-%02d", min(index, 28)),
                inputTokens: index,
                outputTokens: index,
                cacheReadTokens: 0,
                totalTokens: index * 10,
                costUSD: nil,
                modelsUsed: nil,
                modelBreakdowns: nil
            )
        }
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 400,
            sessionCostUSD: nil,
            todayInputTokens: nil,
            todayOutputTokens: nil,
            todayCachedInputTokens: nil,
            rangeDays: nil,
            rangeTokens: nil,
            rangeCostUSD: nil,
            rangeInputTokens: nil,
            rangeOutputTokens: nil,
            rangeCachedInputTokens: nil,
            daily: entries,
            updatedAt: now,
            source: .globalFallback
        )

        let recorder = TrailingDaysRecorder()
        let service = Self.makeService { _, trailingDays, _, _ in
            await recorder.record(trailingDays)
            return snapshot
        }

        let result = try await service.fetchGlobalSnapshot(trailingDays: 7, environment: [:])

        #expect(await recorder.values() == [nil])
        #expect(result.points.count == 7)
        #expect(result.todayTokens == 400)
        #expect(result.last7DaysTokens == (34...40).map { $0 * 10 }.reduce(0, +))
        #expect(result.last30DaysTokens == (11...40).map { $0 * 10 }.reduce(0, +))
        #expect(result.allDaysTokens == (1...40).map { $0 * 10 }.reduce(0, +))
    }

    @Test("returns empty snapshot when scanner has no daily entries")
    func returnsEmptySnapshotWhenNoDailyEntries() async throws {
        let now = Self.makeLocalDate(year: 2026, month: 2, day: 26, hour: 12, minute: 0)
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: nil,
            todayInputTokens: nil,
            todayOutputTokens: nil,
            todayCachedInputTokens: nil,
            rangeDays: nil,
            rangeTokens: nil,
            rangeCostUSD: nil,
            rangeInputTokens: nil,
            rangeOutputTokens: nil,
            rangeCachedInputTokens: nil,
            daily: [],
            updatedAt: now,
            source: .globalFallback
        )

        let service = Self.makeService { _, _, _, _ in snapshot }
        let result = try await service.fetchGlobalSnapshot(trailingDays: nil, environment: [:])

        #expect(result.points.isEmpty)
        #expect(result.todayTokens == 0)
        #expect(result.last7DaysTokens == nil)
        #expect(result.last30DaysTokens == nil)
        #expect(result.allDaysTokens == nil)
    }

    @Test("returns zero for today when latest history point is before current date")
    func returnsZeroForTodayWhenLatestHistoryPointIsBeforeCurrentDate() async throws {
        let now = Self.makeLocalDate(year: 2026, month: 3, day: 1, hour: 9, minute: 0)
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: nil,
            todayInputTokens: nil,
            todayOutputTokens: nil,
            todayCachedInputTokens: nil,
            rangeDays: 30,
            rangeTokens: 390,
            rangeCostUSD: nil,
            rangeInputTokens: nil,
            rangeOutputTokens: nil,
            rangeCachedInputTokens: nil,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2026-02-27",
                    inputTokens: 80,
                    outputTokens: 20,
                    cacheReadTokens: 0,
                    totalTokens: 100,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
                CostUsageDailyReport.Entry(
                    date: "2026-02-28",
                    inputTokens: 200,
                    outputTokens: 90,
                    cacheReadTokens: 0,
                    totalTokens: 290,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil
                ),
            ],
            updatedAt: now,
            source: .scopedSessions
        )

        let service = Self.makeService { _, _, _, _ in snapshot }
        let result = try await service.fetchGlobalSnapshot(trailingDays: 30, environment: [:])

        #expect(result.todayTokens == 0)
        #expect(result.last7DaysTokens == 390)
        #expect(result.last30DaysTokens == 390)
        #expect(result.allDaysTokens == 390)
    }

    @Test("projects UTC minute facts into local day totals for the session-backed snapshot")
    func makeTokenSnapshot_projectsUTCMinutesIntoLocalDays() throws {
        let timezone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let now = try #require(Self.makeUTCDate(year: 2026, month: 4, day: 15, hour: 7, minute: 10))
        let projected = CodexSessionProjectedUsage(
            entries: [
                .init(
                    minuteStartUnixMs: Int64((try #require(Self.makeUTCDate(year: 2026, month: 4, day: 15, hour: 6, minute: 10))).timeIntervalSince1970 * 1_000),
                    inputTokens: 12,
                    cachedInputTokens: 3,
                    outputTokens: 4
                ),
                .init(
                    minuteStartUnixMs: Int64((try #require(Self.makeUTCDate(year: 2026, month: 4, day: 15, hour: 7, minute: 10))).timeIntervalSince1970 * 1_000),
                    inputTokens: 20,
                    cachedInputTokens: 5,
                    outputTokens: 7
                ),
            ],
            updatedAt: now,
            sourceLabel: "global local usage"
        )

        let snapshot = CodexTokenTrendService.makeTokenSnapshot(
            from: projected,
            timezone: timezone,
            now: now
        )

        #expect(snapshot.daily.map(\.date) == ["2026-04-14", "2026-04-15"])
        #expect(snapshot.daily.map(\.totalTokens) == [16, 27])
        #expect(snapshot.sessionTokens == 27)
        #expect(snapshot.todayInputTokens == 20)
        #expect(snapshot.todayCachedInputTokens == 5)
        #expect(snapshot.todayOutputTokens == 7)
        #expect(snapshot.rangeTokens == 43)
    }

    @Test("session-backed snapshot uses wall clock day for today totals")
    func loadSessionBackedSnapshot_usesWallClockDayForTodayTotals() throws {
        let timezone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let now = try #require(Self.makeUTCDate(year: 2026, month: 4, day: 15, hour: 19, minute: 0))
        let yesterdayMinute = try #require(Self.makeUTCDate(year: 2026, month: 4, day: 15, hour: 6, minute: 10))
        let projected = CodexSessionProjectedUsage(
            entries: [
                .init(
                    minuteStartUnixMs: Int64(yesterdayMinute.timeIntervalSince1970 * 1_000),
                    inputTokens: 12,
                    cachedInputTokens: 3,
                    outputTokens: 4
                )
            ],
            updatedAt: yesterdayMinute,
            sourceLabel: "global local usage"
        )

        let snapshot = try CodexTokenTrendService.loadSessionBackedSnapshot(
            environment: ["CODEX_HOME": "/tmp/codex-home"],
            timezone: timezone,
            now: now,
            loadProjectedUsage: { _ in projected }
        )

        #expect(snapshot.daily.map(\.date) == ["2026-04-14"])
        #expect(snapshot.sessionTokens == nil)
        #expect(snapshot.todayInputTokens == nil)
        #expect(snapshot.todayOutputTokens == nil)
        #expect(snapshot.todayCachedInputTokens == nil)
        #expect(snapshot.rangeTokens == 16)
    }

    @Test("persists full codex token trend snapshot after live fetch")
    func fetchGlobalSnapshot_persistsFullSnapshotForStartupHydration() async throws {
        let root = STFolder("/tmp").folder("codex-token-trend-cache-save-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let fullEntries = (1...40).map { index in
            CostUsageDailyReport.Entry(
                date: String(format: "2026-02-%02d", min(index, 28)),
                inputTokens: index,
                outputTokens: index,
                cacheReadTokens: 0,
                totalTokens: index * 10,
                costUSD: nil,
                modelsUsed: nil,
                modelBreakdowns: nil
            )
        }
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 400,
            sessionCostUSD: nil,
            todayInputTokens: nil,
            todayOutputTokens: nil,
            todayCachedInputTokens: nil,
            rangeDays: nil,
            rangeTokens: nil,
            rangeCostUSD: nil,
            rangeInputTokens: nil,
            rangeOutputTokens: nil,
            rangeCachedInputTokens: nil,
            daily: fullEntries,
            updatedAt: Self.makeLocalDate(year: 2026, month: 2, day: 28, hour: 12, minute: 0),
            source: .scopedSessions
        )
        let cacheStore = CodexTokenTrendSnapshotCache(rootDirectory: root.url)
        let service = CodexTokenTrendService(
            loadSnapshot: { _, _, _, _ in snapshot },
            cacheStore: cacheStore,
            loadCachedProjectedUsage: { _, _, _ in nil },
            now: Date.init
        )

        let result = try await service.fetchGlobalSnapshot(trailingDays: 7, environment: [:])
        let persisted = try #require(
            try cacheStore.load(codexHome: CodexTokenTrendService.resolveCodexHomeURL(environment: [:]))
        )

        #expect(result.points.count == 7)
        #expect(persisted.points.count == 40)
        #expect(persisted.allDaysTokens == (1...40).map { $0 * 10 }.reduce(0, +))
    }

    @Test("hydrates cached full snapshot and slices only chart points")
    func fetchCachedGlobalSnapshot_prefersFullSnapshotCache() throws {
        let root = STFolder("/tmp").folder("codex-token-trend-cache-read-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let fullSnapshot = ProviderTokenTrendSnapshot(
            points: (1...40).map { index in
                ProviderTokenTrendPoint(
                    date: String(format: "2026-02-%02d", min(index, 28)),
                    totalTokens: index * 10,
                    inputTokens: index * 6,
                    outputTokens: index * 4,
                    cacheReadTokens: index
                )
            },
            todayTokens: 400,
            last7DaysTokens: (34...40).map { $0 * 10 }.reduce(0, +),
            last30DaysTokens: (11...40).map { $0 * 10 }.reduce(0, +),
            allDaysTokens: (1...40).map { $0 * 10 }.reduce(0, +),
            updatedAt: Self.makeLocalDate(year: 2026, month: 2, day: 28, hour: 12, minute: 0),
            sourceLabel: "global local usage"
        )
        let cacheStore = CodexTokenTrendSnapshotCache(rootDirectory: root.url)
        try cacheStore.save(
            fullSnapshot,
            codexHome: CodexTokenTrendService.resolveCodexHomeURL(environment: [:])
        )
        let service = CodexTokenTrendService(
            loadSnapshot: { _, _, _, _ in
                Issue.record("cached path should not call live loader")
                return CostUsageTokenSnapshot(
                    sessionTokens: nil,
                    sessionCostUSD: nil,
                    todayInputTokens: nil,
                    todayOutputTokens: nil,
                    todayCachedInputTokens: nil,
                    rangeDays: nil,
                    rangeTokens: nil,
                    rangeCostUSD: nil,
                    rangeInputTokens: nil,
                    rangeOutputTokens: nil,
                    rangeCachedInputTokens: nil,
                    daily: [],
                    updatedAt: Date(timeIntervalSince1970: 0),
                    source: .scopedSessions
                )
            },
            cacheStore: cacheStore,
            loadCachedProjectedUsage: { _, _, _ in nil },
            now: Date.init
        )

        let result = try #require(service.fetchCachedGlobalSnapshot(trailingDays: 7, environment: [:]))

        #expect(result.points.count == 7)
        #expect(result.todayTokens == 400)
        #expect(result.last30DaysTokens == fullSnapshot.last30DaysTokens)
        #expect(result.allDaysTokens == fullSnapshot.allDaysTokens)
    }

    @Test("reconciles cached today point from cached minute truth before first live refresh")
    func fetchCachedGlobalSnapshot_reconcilesTodayFromCachedMinuteProjection() throws {
        let root = STFolder("/tmp").folder("codex-token-trend-cache-reconcile-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let timezone = TimeZone.current
        let now = Self.makeLocalDate(year: 2026, month: 4, day: 21, hour: 16, minute: 0)
        let todayKey = CodexTokenTrendService.dayKey(from: now, timezone: timezone)
        let yesterday = Self.makeLocalDate(year: 2026, month: 4, day: 20, hour: 12, minute: 0)
        let yesterdayKey = CodexTokenTrendService.dayKey(from: yesterday, timezone: timezone)
        let fullSnapshot = ProviderTokenTrendSnapshot(
            points: [
                .init(
                    date: yesterdayKey,
                    totalTokens: 200,
                    inputTokens: 150,
                    outputTokens: 50,
                    cacheReadTokens: 20
                ),
                .init(
                    date: todayKey,
                    totalTokens: 300,
                    inputTokens: 240,
                    outputTokens: 60,
                    cacheReadTokens: 30
                ),
            ],
            todayTokens: 300,
            last7DaysTokens: 500,
            last30DaysTokens: 500,
            allDaysTokens: 500,
            updatedAt: yesterday,
            sourceLabel: "global local usage"
        )
        let cacheStore = CodexTokenTrendSnapshotCache(rootDirectory: root.url)
        let codexHome = CodexTokenTrendService.resolveCodexHomeURL(environment: [:])
        try cacheStore.save(
            fullSnapshot,
            codexHome: codexHome
        )

        let startOfToday = try #require(CodexTokenTrendService.dayRange(for: now, timezone: timezone)?.start)
        let projected = CodexSessionProjectedUsage(
            entries: [
                .init(
                    minuteStartUnixMs: Int64(startOfToday.addingTimeInterval(60).timeIntervalSince1970 * 1_000),
                    inputTokens: 400,
                    cachedInputTokens: 40,
                    outputTokens: 80
                ),
                .init(
                    minuteStartUnixMs: Int64(startOfToday.addingTimeInterval(120).timeIntervalSince1970 * 1_000),
                    inputTokens: 200,
                    cachedInputTokens: 20,
                    outputTokens: 20
                ),
            ],
            updatedAt: now,
            sourceLabel: "global local usage"
        )
        let service = CodexTokenTrendService(
            loadSnapshot: { _, _, _, _ in
                Issue.record("cached path should not call live loader")
                return CostUsageTokenSnapshot(
                    sessionTokens: nil,
                    sessionCostUSD: nil,
                    todayInputTokens: nil,
                    todayOutputTokens: nil,
                    todayCachedInputTokens: nil,
                    rangeDays: nil,
                    rangeTokens: nil,
                    rangeCostUSD: nil,
                    rangeInputTokens: nil,
                    rangeOutputTokens: nil,
                    rangeCachedInputTokens: nil,
                    daily: [],
                    updatedAt: Date(timeIntervalSince1970: 0),
                    source: .scopedSessions
                )
            },
            cacheStore: cacheStore,
            loadCachedProjectedUsage: { requestedHome, rangeStart, rangeEnd in
                #expect(requestedHome == codexHome)
                #expect(rangeStart == CodexTokenTrendService.dayRange(for: now, timezone: timezone)?.start)
                #expect(rangeEnd == CodexTokenTrendService.dayRange(for: now, timezone: timezone)?.end)
                return projected
            },
            now: { now }
        )

        let result = try #require(
            service.fetchCachedGlobalSnapshot(
                trailingDays: 30,
                environment: [:]
            )
        )

        #expect(result.points.map(\.date) == [yesterdayKey, todayKey])
        #expect(result.points.map(\.totalTokens) == [200, 700])
        #expect(result.todayTokens == 700)
        #expect(result.last7DaysTokens == 900)
        #expect(result.last30DaysTokens == 900)
        #expect(result.allDaysTokens == 900)
        #expect(result.updatedAt == now)
    }

    @Test("refreshes cached full snapshot by recomputing only affected days from changed files")
    func fetchRefreshedGlobalSnapshot_updatesOnlyAffectedDaysAcrossAllFiles() async throws {
        let root = STFolder("/tmp").folder("codex-token-trend-cache-refresh-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let timezone = TimeZone.current
        let now = Self.makeLocalDate(year: 2026, month: 4, day: 21, hour: 18, minute: 0)
        let todayKey = CodexTokenTrendService.dayKey(from: now, timezone: timezone)
        let yesterdayDate = Self.makeLocalDate(year: 2026, month: 4, day: 20, hour: 12, minute: 0)
        let yesterdayKey = CodexTokenTrendService.dayKey(from: yesterdayDate, timezone: timezone)
        let olderKey = CodexTokenTrendService.dayKey(
            from: Self.makeLocalDate(year: 2026, month: 4, day: 19, hour: 12, minute: 0),
            timezone: timezone
        )

        let fullSnapshot = ProviderTokenTrendSnapshot(
            points: [
                .init(date: olderKey, totalTokens: 100, inputTokens: 60, outputTokens: 40, cacheReadTokens: 10),
                .init(date: yesterdayKey, totalTokens: 200, inputTokens: 150, outputTokens: 50, cacheReadTokens: 20),
                .init(date: todayKey, totalTokens: 300, inputTokens: 240, outputTokens: 60, cacheReadTokens: 30),
            ],
            todayTokens: 300,
            last7DaysTokens: 600,
            last30DaysTokens: 600,
            allDaysTokens: 600,
            updatedAt: yesterdayDate,
            sourceLabel: "global local usage"
        )
        let cacheStore = CodexTokenTrendSnapshotCache(rootDirectory: root.url)
        let codexHome = CodexTokenTrendService.resolveCodexHomeURL(environment: [:])
        try cacheStore.save(fullSnapshot, codexHome: codexHome)
        let projected = CodexSessionProjectedUsage(
            entries: [
                .init(
                    minuteStartUnixMs: Int64(yesterdayDate.addingTimeInterval(60).timeIntervalSince1970 * 1_000),
                    inputTokens: 220,
                    cachedInputTokens: 22,
                    outputTokens: 80
                ),
                .init(
                    minuteStartUnixMs: Int64(yesterdayDate.addingTimeInterval(2 * 60 * 60).timeIntervalSince1970 * 1_000),
                    inputTokens: 110,
                    cachedInputTokens: 11,
                    outputTokens: 40
                ),
                .init(
                    minuteStartUnixMs: Int64(now.addingTimeInterval(-2 * 60 * 60).timeIntervalSince1970 * 1_000),
                    inputTokens: 500,
                    cachedInputTokens: 50,
                    outputTokens: 100
                ),
                .init(
                    minuteStartUnixMs: Int64(now.addingTimeInterval(-60 * 60).timeIntervalSince1970 * 1_000),
                    inputTokens: 150,
                    cachedInputTokens: 15,
                    outputTokens: 50
                ),
            ],
            updatedAt: now,
            sourceLabel: "global local usage"
        )

        let service = CodexTokenTrendService(
            loadSnapshot: { _, _, _, _ in
                Issue.record("incremental refresh should not fall back to full live snapshot when cache exists")
                return CostUsageTokenSnapshot(
                    sessionTokens: nil,
                    sessionCostUSD: nil,
                    todayInputTokens: nil,
                    todayOutputTokens: nil,
                    todayCachedInputTokens: nil,
                    rangeDays: nil,
                    rangeTokens: nil,
                    rangeCostUSD: nil,
                    rangeInputTokens: nil,
                    rangeOutputTokens: nil,
                    rangeCachedInputTokens: nil,
                    daily: [],
                    updatedAt: Date(timeIntervalSince1970: 0),
                    source: .scopedSessions
                )
            },
            cacheStore: cacheStore,
            refreshAffectedDayKeys: { requestedHome, requestedTimezone in
                #expect(requestedHome == codexHome)
                #expect(requestedTimezone == timezone)
                return [todayKey, yesterdayKey]
            },
            loadCachedProjectedUsage: { requestedHome, rangeStart, rangeEnd in
                #expect(requestedHome == codexHome)
                let expectedYesterdayRange = CodexTokenTrendService.dayRange(forDayKey: yesterdayKey, timezone: timezone)
                let expectedTodayRange = CodexTokenTrendService.dayRange(forDayKey: todayKey, timezone: timezone)
                let matchesYesterday = rangeStart == expectedYesterdayRange?.start && rangeEnd == expectedYesterdayRange?.end
                let matchesToday = rangeStart == expectedTodayRange?.start && rangeEnd == expectedTodayRange?.end
                #expect(matchesYesterday || matchesToday)
                let filteredEntries = projected.entries.filter { entry in
                    let minute = entry.minuteStartAt
                    if let rangeStart, minute < rangeStart {
                        return false
                    }
                    if let rangeEnd, minute >= rangeEnd {
                        return false
                    }
                    return true
                }
                return filteredEntries.isEmpty
                    ? nil
                    : CodexSessionProjectedUsage(
                        entries: filteredEntries,
                        updatedAt: projected.updatedAt,
                        sourceLabel: projected.sourceLabel
                    )
            },
            now: { now }
        )

        let result = try await service.fetchRefreshedGlobalSnapshot(trailingDays: 30, environment: [:])

        #expect(result.points.map(\.date) == [olderKey, yesterdayKey, todayKey])
        #expect(result.points.map(\.totalTokens) == [100, 450, 800])
        #expect(result.todayTokens == 800)
        #expect(result.last7DaysTokens == 1_350)
        #expect(result.last30DaysTokens == 1_350)
        #expect(result.allDaysTokens == 1_350)
        #expect(result.updatedAt == now)
    }

    @Test("keeps today's cached minute reconciliation even when no day keys are affected")
    func fetchRefreshedGlobalSnapshot_keepsTodayReconciledWhenNothingChanged() async throws {
        let root = STFolder("/tmp").folder("codex-token-trend-cache-noop-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let now = Self.makeLocalDate(year: 2026, month: 4, day: 21, hour: 18, minute: 0)
        let cacheStore = CodexTokenTrendSnapshotCache(rootDirectory: root.url)
        let codexHome = CodexTokenTrendService.resolveCodexHomeURL(environment: [:])
        let cachedSnapshot = ProviderTokenTrendSnapshot(
            points: [
                .init(date: "2026-04-20", totalTokens: 200, inputTokens: 150, outputTokens: 50, cacheReadTokens: 20),
                .init(date: "2026-04-21", totalTokens: 300, inputTokens: 240, outputTokens: 60, cacheReadTokens: 30),
            ],
            todayTokens: 300,
            last7DaysTokens: 500,
            last30DaysTokens: 500,
            allDaysTokens: 500,
            updatedAt: now,
            sourceLabel: "global local usage"
        )
        try cacheStore.save(cachedSnapshot, codexHome: codexHome)

        let projectedUsageCalls = ReloadCounter()
        let todayRange = try #require(CodexTokenTrendService.dayRange(for: now, timezone: .current))
        let reconciledProjectedUsage = CodexSessionProjectedUsage(
            entries: [
                .init(
                    minuteStartUnixMs: Int64(todayRange.start.addingTimeInterval(60).timeIntervalSince1970 * 1_000),
                    inputTokens: 400,
                    cachedInputTokens: 40,
                    outputTokens: 80
                ),
                .init(
                    minuteStartUnixMs: Int64(todayRange.start.addingTimeInterval(120).timeIntervalSince1970 * 1_000),
                    inputTokens: 200,
                    cachedInputTokens: 20,
                    outputTokens: 20
                ),
            ],
            updatedAt: now.addingTimeInterval(30),
            sourceLabel: "global local usage"
        )
        let service = CodexTokenTrendService(
            loadSnapshot: { _, _, _, _ in
                Issue.record("cached incremental path should not fall back to full live snapshot")
                return CostUsageTokenSnapshot(
                    sessionTokens: nil,
                    sessionCostUSD: nil,
                    todayInputTokens: nil,
                    todayOutputTokens: nil,
                    todayCachedInputTokens: nil,
                    rangeDays: nil,
                    rangeTokens: nil,
                    rangeCostUSD: nil,
                    rangeInputTokens: nil,
                    rangeOutputTokens: nil,
                    rangeCachedInputTokens: nil,
                    daily: [],
                    updatedAt: Date(timeIntervalSince1970: 0),
                    source: .scopedSessions
                )
            },
            cacheStore: cacheStore,
            refreshAffectedDayKeys: { requestedHome, requestedTimezone in
                #expect(requestedHome == codexHome)
                #expect(requestedTimezone == .current)
                return []
            },
            loadCachedProjectedUsage: { requestedHome, rangeStart, rangeEnd in
                #expect(requestedHome == codexHome)
                #expect(rangeStart == todayRange.start)
                #expect(rangeEnd == todayRange.end)
                projectedUsageCalls.increment()
                return reconciledProjectedUsage
            },
            now: { now }
        )

        let result = try await service.fetchRefreshedGlobalSnapshot(trailingDays: 30, environment: [:])

        #expect(result.points.map(\.date) == ["2026-04-20", "2026-04-21"])
        #expect(result.points.map(\.totalTokens) == [200, 700])
        #expect(result.todayTokens == 700)
        #expect(result.last7DaysTokens == 900)
        #expect(result.last30DaysTokens == 900)
        #expect(result.allDaysTokens == 900)
        #expect(result.updatedAt == reconciledProjectedUsage.updatedAt)
        #expect(projectedUsageCalls.value == 1)
    }
}

private actor TrailingDaysRecorder {
    private var storage: [Int?] = []

    func record(_ value: Int?) {
        storage.append(value)
    }

    func values() -> [Int?] {
        storage
    }
}

private final class ReloadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private extension CodexTokenTrendServiceTests {
    static func makeService(
        loadSnapshot: @escaping CodexTokenTrendService.SnapshotLoader
    ) -> CodexTokenTrendService {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-token-trend-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return CodexTokenTrendService(
            loadSnapshot: loadSnapshot,
            cacheStore: CodexTokenTrendSnapshotCache(rootDirectory: root),
            loadCachedProjectedUsage: { _, _, _ in nil },
            now: Date.init
        )
    }

    static func makeLocalDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone.current
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return comps.date ?? Date(timeIntervalSince1970: 0)
    }

    static func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        var comps = DateComponents()
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.date(from: comps)
    }
}
