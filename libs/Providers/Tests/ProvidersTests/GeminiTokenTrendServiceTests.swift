import Foundation
import Testing
@testable import ProviderUsage

@Suite("GeminiTokenTrendService")
struct GeminiTokenTrendServiceTests {
    @Test("Aggregates active Gemini session tokens into daily trend points")
    func fetchActiveSnapshot_aggregatesSessionFiles() async throws {
        let globalGeminiURL = URL(fileURLWithPath: "/Users/tester/.gemini", isDirectory: true)
        let service = GeminiTokenTrendService(
            loadActiveAccount: { provider in
                #expect(provider == .gemini)
                return GeminiAuthAccount(
                    id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
                    providerID: .gemini,
                    name: "Gemini",
                    method: .oauthPersonal,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    lastUsedAt: nil,
                    lastLoginAt: nil,
                    email: "dev@example.com",
                    project: nil,
                    location: nil,
                    runtimeHomeRelativePath: "accounts/runtime/home"
                )
            },
            loadSessionRoot: { globalGeminiURL },
            listSessionFiles: { root in
                #expect(root.path == globalGeminiURL.path)
                return [
                    globalGeminiURL.appendingPathComponent("tmp/project-a/chats/session-1.json"),
                    globalGeminiURL.appendingPathComponent("tmp/project-b/chats/session-2.json"),
                ]
            },
            readFile: { url in
                switch url.lastPathComponent {
                case "session-1.json":
                    return """
                    {
                      "messages": [
                        {
                          "type": "gemini",
                          "timestamp": "2026-03-08T02:00:00Z",
                          "tokens": {
                            "input": 100,
                            "output": 40,
                            "cached": 25,
                            "total": 140
                          }
                        },
                        {
                          "type": "gemini",
                          "timestamp": "2026-03-08T05:30:00Z",
                          "tokens": {
                            "input": 60,
                            "output": 20,
                            "cached": 10,
                            "total": 80
                          }
                        }
                      ]
                    }
                    """
                case "session-2.json":
                    return """
                    {
                      "messages": [
                        {
                          "type": "user",
                          "timestamp": "2026-03-07T01:00:00Z"
                        },
                        {
                          "type": "gemini",
                          "timestamp": "2026-03-07T09:15:00Z",
                          "tokens": {
                            "input": 80,
                            "output": 30,
                            "cached": 5,
                            "total": 110
                          }
                        },
                        {
                          "type": "gemini",
                          "timestamp": "2026-03-07T10:00:00Z"
                        }
                      ]
                    }
                    """
                default:
                    Issue.record("Unexpected session file: \(url.path)")
                    return "{}"
                }
            },
            now: { Self.makeLocalDate(year: 2026, month: 3, day: 8, hour: 12, minute: 0) }
        )

        let snapshot = try #require(await service.fetchActiveSnapshot(provider: .gemini))

        #expect(snapshot.points == [
            ProviderTokenTrendPoint(
                date: "2026-03-07",
                totalTokens: 110,
                inputTokens: 80,
                outputTokens: 30,
                cacheReadTokens: 5,
                requestCount: 1
            ),
            ProviderTokenTrendPoint(
                date: "2026-03-08",
                totalTokens: 220,
                inputTokens: 160,
                outputTokens: 60,
                cacheReadTokens: 35,
                requestCount: 2
            ),
        ])
        #expect(snapshot.todayTokens == 220)
        #expect(snapshot.todayRequests == 2)
        #expect(snapshot.last7DaysTokens == 330)
        #expect(snapshot.last7DaysRequests == 3)
        #expect(snapshot.last30DaysTokens == 330)
        #expect(snapshot.last30DaysRequests == 3)
        #expect(snapshot.allDaysTokens == 330)
        #expect(snapshot.allDaysRequests == 3)
        #expect(snapshot.sourceLabel == "session")
    }

    @Test("Returns nil when no active Gemini account exists")
    func fetchActiveSnapshot_returnsNilWithoutActiveAccount() async throws {
        let service = GeminiTokenTrendService(
            loadActiveAccount: { _ in nil },
            loadSessionRoot: {
                Issue.record("Should not resolve session root without active account")
                return URL(fileURLWithPath: "/tmp/unused", isDirectory: true)
            },
            listSessionFiles: { _ in
                Issue.record("Should not list session files without active account")
                return []
            },
            readFile: { _ in
                Issue.record("Should not read files without active account")
                return "{}"
            }
        )

        let snapshot = try await service.fetchActiveSnapshot(provider: .gemini)
        #expect(snapshot == nil)
    }

    @Test("Applies trailing day window to aggregated Gemini trend points")
    func fetchActiveSnapshot_appliesTrailingDays() async throws {
        let globalGeminiURL = URL(fileURLWithPath: "/Users/tester/.gemini", isDirectory: true)
        let service = GeminiTokenTrendService(
            loadActiveAccount: { _ in
                GeminiAuthAccount(
                    id: UUID(uuidString: "ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee")!,
                    providerID: .gemini,
                    name: "Gemini",
                    method: .oauthPersonal,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    lastUsedAt: nil,
                    lastLoginAt: nil,
                    email: "dev@example.com",
                    project: nil,
                    location: nil,
                    runtimeHomeRelativePath: "accounts/runtime/home"
                )
            },
            loadSessionRoot: { globalGeminiURL },
            listSessionFiles: { root in
                #expect(root.path == globalGeminiURL.path)
                return [globalGeminiURL.appendingPathComponent("tmp/project-a/chats/session-1.json")]
            },
            readFile: { _ in
                """
                {
                  "messages": [
                    { "type": "gemini", "timestamp": "2026-03-01T01:00:00Z", "tokens": { "input": 10, "output": 5, "cached": 0, "total": 15 } },
                    { "type": "gemini", "timestamp": "2026-03-02T01:00:00Z", "tokens": { "input": 20, "output": 5, "cached": 0, "total": 25 } },
                    { "type": "gemini", "timestamp": "2026-03-03T01:00:00Z", "tokens": { "input": 30, "output": 5, "cached": 0, "total": 35 } }
                  ]
                }
                """
            },
            now: { Self.makeLocalDate(year: 2026, month: 3, day: 3, hour: 12, minute: 0) }
        )

        let snapshot = try #require(await service.fetchActiveSnapshot(provider: .gemini, trailingDays: 2))

        #expect(snapshot.points.map(\.date) == ["2026-03-02", "2026-03-03"])
        #expect(snapshot.todayTokens == 35)
        #expect(snapshot.last7DaysTokens == 75)
        #expect(snapshot.last30DaysTokens == 75)
        #expect(snapshot.allDaysTokens == 75)
    }

    @Test("Reads Gemini session files only from global Gemini directory")
    func fetchActiveSnapshot_readsOnlyGlobalGeminiDirectory() async throws {
        let globalGeminiURL = URL(fileURLWithPath: "/Users/tester/.gemini", isDirectory: true)
        let service = GeminiTokenTrendService(
            loadActiveAccount: { _ in
                GeminiAuthAccount(
                    id: UUID(uuidString: "11111111-bbbb-cccc-dddd-eeeeeeeeeeee")!,
                    providerID: .gemini,
                    name: "Gemini",
                    method: .oauthPersonal,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    lastUsedAt: nil,
                    lastLoginAt: nil,
                    email: "dev@example.com",
                    project: nil,
                    location: nil,
                    runtimeHomeRelativePath: "accounts/runtime/home"
                )
            },
            loadSessionRoot: { globalGeminiURL },
            listSessionFiles: { root in
                #expect(root.path == globalGeminiURL.path)
                return [globalGeminiURL.appendingPathComponent("tmp/project/chats/session-1.json")]
            },
            readFile: { url in
                #expect(url.lastPathComponent == "session-1.json")
                return """
                {
                  "messages": [
                    {
                      "type": "gemini",
                      "timestamp": "2026-03-08T02:00:00Z",
                      "tokens": {
                        "input": 120,
                        "output": 30,
                        "cached": 10,
                        "total": 150
                      }
                    }
                  ]
                }
                """
            },
            now: { Self.makeLocalDate(year: 2026, month: 3, day: 8, hour: 12, minute: 0) }
        )

        let snapshot = try #require(await service.fetchActiveSnapshot(provider: .gemini))

        #expect(snapshot.points == [
            ProviderTokenTrendPoint(
                date: "2026-03-08",
                totalTokens: 150,
                inputTokens: 120,
                outputTokens: 30,
                cacheReadTokens: 10,
                requestCount: 1
            ),
        ])
        #expect(snapshot.todayTokens == 150)
        #expect(snapshot.todayRequests == 1)
        #expect(snapshot.last7DaysTokens == 150)
        #expect(snapshot.last7DaysRequests == 1)
        #expect(snapshot.last30DaysTokens == 150)
        #expect(snapshot.last30DaysRequests == 1)
        #expect(snapshot.allDaysTokens == 150)
        #expect(snapshot.allDaysRequests == 1)
    }

    @Test("Returns zero for today when latest Gemini session is before current date")
    func fetchActiveSnapshot_returnsZeroWhenTodayHasNoUsageYet() async throws {
        let globalGeminiURL = URL(fileURLWithPath: "/Users/tester/.gemini", isDirectory: true)
        let service = GeminiTokenTrendService(
            loadActiveAccount: { _ in
                GeminiAuthAccount(
                    id: UUID(uuidString: "22222222-bbbb-cccc-dddd-eeeeeeeeeeee")!,
                    providerID: .gemini,
                    name: "Gemini",
                    method: .oauthPersonal,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    lastUsedAt: nil,
                    lastLoginAt: nil,
                    email: "dev@example.com",
                    project: nil,
                    location: nil,
                    runtimeHomeRelativePath: "accounts/runtime/home"
                )
            },
            loadSessionRoot: { globalGeminiURL },
            listSessionFiles: { _ in
                [globalGeminiURL.appendingPathComponent("tmp/project/chats/session-1.json")]
            },
            readFile: { _ in
                """
                {
                  "messages": [
                    { "type": "gemini", "timestamp": "2026-03-07T02:00:00Z", "tokens": { "input": 100, "output": 30, "cached": 10, "total": 130 } },
                    { "type": "gemini", "timestamp": "2026-03-08T02:00:00Z", "tokens": { "input": 50, "output": 20, "cached": 5, "total": 70 } }
                  ]
                }
                """
            },
            now: { Self.makeLocalDate(year: 2026, month: 3, day: 9, hour: 8, minute: 0) }
        )

        let snapshot = try #require(await service.fetchActiveSnapshot(provider: .gemini))

        #expect(snapshot.todayTokens == 0)
        #expect(snapshot.last7DaysTokens == 200)
        #expect(snapshot.last30DaysTokens == 200)
        #expect(snapshot.allDaysTokens == 200)
    }

    @Test("Reuses parsed Gemini session cache between daily trend and intraday drilldown")
    func fetchActiveSnapshot_reusesParsedSessionCacheBetweenTrendAndIntraday() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-gemini-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionFileURL = root
            .appendingPathComponent("tmp/project-a/chats/session-1.json")
        try FileManager.default.createDirectory(
            at: sessionFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        {
          "messages": [
            {
              "type": "gemini",
              "timestamp": "2026-03-08T09:10:00Z",
              "tokens": { "input": 100, "output": 40, "cached": 20, "total": 140 }
            },
            {
              "type": "gemini",
              "timestamp": "2026-03-08T09:40:00Z",
              "tokens": { "input": 60, "output": 30, "cached": 10, "total": 90 }
            }
          ]
        }
        """.write(to: sessionFileURL, atomically: true, encoding: .utf8)

        let cacheFileURL = root.appendingPathComponent("gemini-usage-cache.json")
        let store = GeminiSessionUsageStore(cacheFileURL: cacheFileURL)
        let recorder = ReadFileRecorder()
        let readFile: @Sendable (URL) throws -> String = { url in
            recorder.record(url)
            return try String(contentsOf: url, encoding: .utf8)
        }

        let trendService = GeminiTokenTrendService(
            loadActiveAccount: { _ in Self.makeActiveAccount() },
            loadSessionRoot: { root },
            listSessionFiles: { _ in [sessionFileURL] },
            readFile: readFile,
            usageStore: store,
            now: { Self.makeLocalDate(year: 2026, month: 3, day: 8, hour: 18, minute: 0) }
        )
        let intradayService = GeminiIntradayUsageService(
            loadActiveAccount: { _ in Self.makeActiveAccount() },
            loadSessionRoot: { root },
            listSessionFiles: { _ in [sessionFileURL] },
            readFile: readFile,
            usageStore: store,
            now: { Self.makeLocalDate(year: 2026, month: 3, day: 8, hour: 18, minute: 0) }
        )

        let trendSnapshot = try #require(await trendService.fetchActiveSnapshot(provider: .gemini))
        let intradaySnapshot = try #require(
            await intradayService.fetchActiveSnapshot(
                provider: .gemini,
                dayKey: "2026-03-08",
                bucket: ProviderIntradayBucket.minute30,
                timezone: TimeZone(secondsFromGMT: 0) ?? .current
            )
        )

        #expect(trendSnapshot.points.map { $0.totalTokens } == [230])
        #expect(intradaySnapshot.points.map { $0.totalTokens } == [140, 90])
        #expect(recorder.count == 1)
    }

    @Test("Invalidates cached Gemini session parse when file content changes")
    func fetchActiveSnapshot_invalidatesCachedSessionParseWhenFileChanges() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-gemini-cache-refresh-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionFileURL = root
            .appendingPathComponent("tmp/project-a/chats/session-1.json")
        try FileManager.default.createDirectory(
            at: sessionFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        func writeSessionFile(total: Int) throws {
            try """
            {
              "messages": [
                {
                  "type": "gemini",
                  "timestamp": "2026-03-08T09:10:00Z",
                  "tokens": { "input": \(total - 40), "output": 40, "cached": 0, "total": \(total) }
                }
              ]
            }
            """.write(to: sessionFileURL, atomically: true, encoding: .utf8)
        }

        try writeSessionFile(total: 140)

        let cacheFileURL = root.appendingPathComponent("gemini-usage-cache.json")
        let store = GeminiSessionUsageStore(cacheFileURL: cacheFileURL)
        let recorder = ReadFileRecorder()
        let service = GeminiTokenTrendService(
            loadActiveAccount: { _ in Self.makeActiveAccount() },
            loadSessionRoot: { root },
            listSessionFiles: { _ in [sessionFileURL] },
            readFile: { url in
                recorder.record(url)
                return try String(contentsOf: url, encoding: .utf8)
            },
            usageStore: store,
            now: { Self.makeLocalDate(year: 2026, month: 3, day: 8, hour: 18, minute: 0) }
        )

        let first = try #require(await service.fetchActiveSnapshot(provider: .gemini))
        #expect(first.points.map { $0.totalTokens } == [140])

        try writeSessionFile(total: 240)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_762_000_000)],
            ofItemAtPath: sessionFileURL.path
        )

        let second = try #require(await service.fetchActiveSnapshot(provider: .gemini))
        #expect(second.points.map { $0.totalTokens } == [240])
        #expect(recorder.count == 2)
    }

    @Test("Reuses merged Gemini snapshot when file list and fingerprints are unchanged")
    func loadSnapshot_reusesMergedSnapshotWhenInputsAreUnchanged() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-gemini-snapshot-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionFileURL = root
            .appendingPathComponent("project-a/chats/session-1.json")
        try FileManager.default.createDirectory(
            at: sessionFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        {
          "messages": [
            {
              "type": "gemini",
              "timestamp": "2026-03-08T09:10:00Z",
              "tokens": { "input": 100, "output": 40, "cached": 20, "total": 140 }
            }
          ]
        }
        """.write(to: sessionFileURL, atomically: true, encoding: .utf8)

        let store = GeminiSessionUsageStore(cacheFileURL: nil)
        let fingerprint = GeminiSessionFileFingerprint(mtimeUnixMs: 1_762_000_000_000, size: 128)

        let first = try await store.loadSnapshot(
            sessionFiles: [sessionFileURL],
            readFile: { url in
                try String(contentsOf: url, encoding: .utf8)
            },
            loadFileFingerprint: { _ in fingerprint }
        )
        let second = try await store.loadSnapshot(
            sessionFiles: [sessionFileURL],
            readFile: { _ in
                Issue.record("Merged snapshot cache miss should not reread unchanged session files")
                return "{}"
            },
            loadFileFingerprint: { _ in fingerprint }
        )

        #expect(first == second)
#if DEBUG
        let stats = await store.snapshotCacheStatsForTesting()
        #expect(stats.hits == 1)
        #expect(stats.misses == 1)
#endif
    }
}

private extension GeminiTokenTrendServiceTests {
    static func makeActiveAccount() -> GeminiAuthAccount {
        GeminiAuthAccount(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            providerID: .gemini,
            name: "Gemini",
            method: .oauthPersonal,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastUsedAt: nil,
            lastLoginAt: nil,
            email: "dev@example.com",
            project: nil,
            location: nil,
            runtimeHomeRelativePath: "accounts/runtime/home"
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
}

private final class ReadFileRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ _: URL) {
        lock.lock()
        storage += 1
        lock.unlock()
    }
}
