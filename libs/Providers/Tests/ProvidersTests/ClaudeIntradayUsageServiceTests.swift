import Foundation
import Testing
@testable import ProviderUsage

@Suite("ClaudeIntradayUsageService")
struct ClaudeIntradayUsageServiceTests {
    @Test("Aggregates selected Claude day into 30min buckets with streaming dedupe")
    func fetchActiveSnapshot_aggregatesSelectedDayIntoBuckets() async throws {
        let root = URL(fileURLWithPath: "/Users/tester/.claude", isDirectory: true)
        let timezone = try #require(TimeZone(secondsFromGMT: 0))
        let service = ClaudeIntradayUsageService(
            loadActiveAccount: {
                ClaudeAccount(
                    id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
                    name: "Claude",
                    credentialType: .authToken,
                    credentialValue: "token",
                    baseURL: "https://api.anthropic.com",
                    source: .manual
                )
            },
            loadProjectsRoots: { [root] },
            listSessionFiles: { _ in
                [root.appendingPathComponent("project-a/session-a.jsonl")]
            },
            readFile: { _ in
                """
                {"type":"assistant","timestamp":"2026-03-08T09:10:00Z","sessionId":"session-a","requestId":"req-a","message":{"id":"msg-a","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"cache_creation_input_tokens":20,"cache_read_input_tokens":5,"output_tokens":12}}}
                {"type":"assistant","timestamp":"2026-03-08T09:20:00Z","sessionId":"session-a","requestId":"req-a","message":{"id":"msg-a","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"cache_creation_input_tokens":20,"cache_read_input_tokens":5,"output_tokens":40}}}
                {"type":"assistant","timestamp":"2026-03-08T09:40:00Z","message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":60,"cache_creation_input_tokens":0,"cache_read_input_tokens":10,"output_tokens":20}}}
                {"type":"assistant","timestamp":"2026-03-09T09:10:00Z","message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":999,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}
                """
            },
            now: {
                Self.makeDate(
                    year: 2026,
                    month: 3,
                    day: 8,
                    hour: 18,
                    minute: 0,
                    timezone: timezone
                )
            }
        )

        let snapshot = try #require(
            await service.fetchActiveSnapshot(
                dayKey: "2026-03-08",
                bucket: .minute30,
                timezone: timezone
            )
        )

        #expect(snapshot.dayKey == "2026-03-08")
        #expect(snapshot.timezoneIdentifier == timezone.identifier)
        #expect(snapshot.bucket == .minute30)
        #expect(snapshot.actualBucketCount == 2)
        #expect(snapshot.points.count == 2)
        #expect(snapshot.points[0].totalTokens == 165)
        #expect(snapshot.points[0].inputTokens == 120)
        #expect(snapshot.points[0].outputTokens == 40)
        #expect(snapshot.points[0].cacheReadTokens == 5)
        #expect(snapshot.points[1].totalTokens == 90)
        #expect(snapshot.points[1].inputTokens == 60)
        #expect(snapshot.points[1].outputTokens == 20)
        #expect(snapshot.points[1].cacheReadTokens == 10)
        #expect(snapshot.sourceLabel == "session")
    }

    @Test("Returns nil when no active Claude account exists")
    func fetchActiveSnapshot_returnsNilWithoutActiveAccount() async throws {
        let service = ClaudeIntradayUsageService(
            loadActiveAccount: { nil },
            loadProjectsRoots: {
                Issue.record("Should not resolve Claude project roots without active account")
                return []
            },
            listSessionFiles: { _ in
                Issue.record("Should not list Claude project files without active account")
                return []
            },
            readFile: { _ in
                Issue.record("Should not read Claude project files without active account")
                return ""
            }
        )

        let snapshot = try await service.fetchActiveSnapshot(
            dayKey: "2026-03-08",
            bucket: .minute30
        )
        #expect(snapshot == nil)
    }
}

private extension ClaudeIntradayUsageServiceTests {
    static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timezone: TimeZone
    ) -> Date {
        var comps = DateComponents()
        comps.calendar = Calendar(identifier: .gregorian)
        comps.timeZone = timezone
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return comps.date ?? Date(timeIntervalSince1970: 0)
    }
}
