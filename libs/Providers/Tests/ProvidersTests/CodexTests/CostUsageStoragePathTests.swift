import Foundation
import Testing
import STFilePath
import CodexBarProviderCatalog
@testable import CodexProvider

@Suite("Cost Usage STFilePath")
struct CostUsageStoragePathTests {
    @Test("CostUsageCacheIO default cache path keeps CodexBar layout")
    func costUsageCacheDefaultPathLayout() {
        let file = CostUsageCacheIO.cacheFile(provider: .codex)
        #expect(file.url.path.hasSuffix("/CodexBar/cost-usage/codex-v1.json"))
    }

    @Test("CostUsageCacheIO supports STFolder cache root")
    func costUsageCacheIOSupportsSTFolder() throws {
        let root = STFolder("/tmp")
            .folder("cost-usage-cache-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let sample = CostUsageCache(
            version: 1,
            lastScanUnixMs: 12_345,
            files: [:],
            days: ["2026-02-12": ["gpt-5": [10, 3, 2]]]
        )

        CostUsageCacheIO.save(provider: .codex, cache: sample, cacheRoot: root)
        let loaded = CostUsageCacheIO.load(provider: .codex, cacheRoot: root)

        #expect(loaded.lastScanUnixMs == 12_345)
        #expect(loaded.days["2026-02-12"]?["gpt-5"] == [10, 3, 2])
    }

    @Test("CostUsageScanner supports STFolder options and STFile parsing")
    func costUsageScannerSupportsSTFilePathTypes() throws {
        let root = STFolder("/tmp")
            .folder("cost-usage-scanner-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let sessionsRoot = root.folder("sessions")
        _ = sessionsRoot.createIfNotExists()

        try sessionsRoot.file("2026-02-12-rollout.jsonl").overlay(with: """
        {"timestamp":"2026-02-12T10:00:00Z","type":"turn_context","payload":{"model":"gpt-5"}}
        {"timestamp":"2026-02-12T10:00:01Z","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":10,"cached_input_tokens":4,"output_tokens":3,"total_tokens":13}}}}
        """)

        let since = Date(timeIntervalSince1970: 0)
        let until = Self.makeLocalDate(year: 2100, month: 1, day: 1, hour: 0, minute: 0)

        let options = CostUsageScanner.Options(
            codexSessionsRoot: sessionsRoot,
            cacheRoot: root.folder("cache"),
            forceRescan: true
        )
        #expect(options.codexSessionsRoot?.path == sessionsRoot.path)
        #expect(options.cacheRoot?.path == root.folder("cache").path)

        let range = CostUsageScanner.CostUsageDayRange(since: since, until: until)
        let parsed = CostUsageScanner.parseCodexFile(
            file: sessionsRoot.file("2026-02-12-rollout.jsonl"),
            range: range
        )
        #expect(parsed.parsedBytes > 0)
        #expect(parsed.lastModel == "gpt-5" || parsed.lastModel == nil)
    }

    @Test("CostUsageScanner aggregates token deltas from parser reduction")
    func costUsageScannerAggregatesReducedUsageDeltas() throws {
        let root = STFolder("/tmp")
            .folder("cost-usage-delta-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let sessionsRoot = root.folder("sessions")
        _ = sessionsRoot.createIfNotExists()
        let file = sessionsRoot.file("2026-02-12-rollout.jsonl")
        try file.overlay(with: """
        {"timestamp":"2026-02-12T10:00:00Z","type":"session_meta","payload":{"id":"session-1"}}
        {"timestamp":"2026-02-12T10:00:01Z","type":"turn_context","payload":{"model":"gpt-5"}}
        {"timestamp":"2026-02-12T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":80,"output_tokens":20,"total_tokens":120}}}}
        {"timestamp":"2026-02-12T10:00:03Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":120,"cached_input_tokens":140,"output_tokens":35,"total_tokens":155}}}}
        {"timestamp":"2026-02-12T10:00:04Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":3,"cached_input_tokens":10,"output_tokens":2,"total_tokens":5}}}}
        {"timestamp":"2026-02-12T10:00:05Z","type":"event_msg","payload":{"type":"warning","message":"noop"}}
        """)

        let since = Date(timeIntervalSince1970: 0)
        let until = Self.makeLocalDate(year: 2100, month: 1, day: 1, hour: 0, minute: 0)
        let range = CostUsageScanner.CostUsageDayRange(since: since, until: until)

        let parsed = CostUsageScanner.parseCodexFile(file: file, range: range)
        #expect(parsed.sessionId == "session-1")
        #expect(parsed.lastModel == "gpt-5")
        #expect(parsed.lastTotals?.input == 120)
        #expect(parsed.lastTotals?.cached == 140)
        #expect(parsed.lastTotals?.output == 35)
        #expect(parsed.days["2026-02-12"]?["gpt-5"] == [123, 103, 37])
    }

    @Test("CostUsageScanner aggregates quarter-hour fact buckets from timestamps")
    func costUsageScannerAggregatesQuarterHours() throws {
        let root = STFolder("/tmp")
            .folder("cost-usage-quarter-hours-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let sessionsRoot = root.folder("sessions")
        _ = sessionsRoot.createIfNotExists()
        let file = sessionsRoot.file("2026-02-12-rollout.jsonl")
        try file.overlay(with: """
        {"timestamp":"2026-02-12T10:00:00+08:00","type":"turn_context","payload":{"model":"gpt-5"}}
        {"timestamp":"2026-02-12T10:01:00+08:00","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":10,"cached_input_tokens":4,"output_tokens":3,"total_tokens":13}}}}
        {"timestamp":"2026-02-12T10:16:00+08:00","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":7,"cached_input_tokens":2,"output_tokens":5,"total_tokens":12}}}}
        {"timestamp":"2026-02-12T10:44:00+08:00","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":9,"cached_input_tokens":1,"output_tokens":4,"total_tokens":13}}}}
        """)

        let since = Date(timeIntervalSince1970: 0)
        let until = Self.makeLocalDate(year: 2100, month: 1, day: 1, hour: 0, minute: 0)
        let range = CostUsageScanner.CostUsageDayRange(since: since, until: until)

        let parsed = CostUsageScanner.parseCodexFile(file: file, range: range)
        #expect(parsed.quarterHours["2026-02-12"]?["10:00"] == [10, 4, 3])
        #expect(parsed.quarterHours["2026-02-12"]?["10:15"] == [7, 2, 5])
        #expect(parsed.quarterHours["2026-02-12"]?["10:30"] == [9, 1, 4])
    }

    @Test("CostUsageScanner parses last JSONL line without trailing newline")
    func costUsageScannerParsesLastLineWithoutTrailingNewline() throws {
        let root = STFolder("/tmp")
            .folder("cost-usage-no-newline-\(UUID().uuidString)")
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let sessionsRoot = root.folder("sessions")
        _ = sessionsRoot.createIfNotExists()
        let file = sessionsRoot.file("2026-02-12-rollout.jsonl")

        let lines = [
            #"{"timestamp":"2026-02-12T10:00:00Z","type":"turn_context","payload":{"model":"gpt-5"}}"#,
            #"{"timestamp":"2026-02-12T10:00:01Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":80,"output_tokens":20,"total_tokens":120}}}}"#,
            #"{"timestamp":"2026-02-12T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":3,"cached_input_tokens":10,"output_tokens":2,"total_tokens":5}}}}"#
        ]
        // Intentionally do not append trailing newline to the last line.
        try file.overlay(with: lines.joined(separator: "\n"))

        let since = Date(timeIntervalSince1970: 0)
        let until = Self.makeLocalDate(year: 2100, month: 1, day: 1, hour: 0, minute: 0)
        let range = CostUsageScanner.CostUsageDayRange(since: since, until: until)

        let parsed = CostUsageScanner.parseCodexFile(file: file, range: range)
        #expect(parsed.days["2026-02-12"]?["gpt-5"] == [103, 83, 22])
    }

    private static func makeLocalDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
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
