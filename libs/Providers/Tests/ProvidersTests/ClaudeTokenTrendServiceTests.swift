import Foundation
import Testing
@testable import ProviderUsage

@Suite("ClaudeTokenTrendService")
struct ClaudeTokenTrendServiceTests {
    @Test("Aggregates active Claude project logs into daily trend points and keeps the last streaming chunk")
    func fetchActiveSnapshot_aggregatesProjectLogs() async throws {
        let root = URL(fileURLWithPath: "/Users/tester/.claude", isDirectory: true)
        let service = ClaudeTokenTrendService(
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
            listSessionFiles: { roots in
                #expect(roots.map { $0.path } == [root.path])
                return [
                    root.appendingPathComponent("project-a/session-a.jsonl"),
                    root.appendingPathComponent("project-b/session-b.jsonl"),
                ]
            },
            readFile: { url in
                switch url.lastPathComponent {
                case "session-a.jsonl":
                    return """
                    {"type":"assistant","timestamp":"2026-03-08T09:10:00Z","sessionId":"session-a","requestId":"req-a","message":{"id":"msg-a","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"cache_creation_input_tokens":20,"cache_read_input_tokens":5,"output_tokens":12}}}
                    {"type":"assistant","timestamp":"2026-03-08T09:20:00Z","sessionId":"session-a","requestId":"req-a","message":{"id":"msg-a","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"cache_creation_input_tokens":20,"cache_read_input_tokens":5,"output_tokens":40}}}
                    """
                case "session-b.jsonl":
                    return """
                    {"type":"assistant","timestamp":"2026-03-07T09:15:00Z","message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":80,"cache_creation_input_tokens":10,"cache_read_input_tokens":5,"output_tokens":20}}}
                    """
                default:
                    Issue.record("Unexpected session file: \(url.path)")
                    return ""
                }
            },
            now: { Self.makeLocalDate(year: 2026, month: 3, day: 8, hour: 20, minute: 0) }
        )

        let snapshot = try #require(await service.fetchActiveSnapshot())

        #expect(snapshot.points == [
            ProviderTokenTrendPoint(
                date: "2026-03-07",
                totalTokens: 115,
                inputTokens: 90,
                outputTokens: 20,
                cacheReadTokens: 5
            ),
            ProviderTokenTrendPoint(
                date: "2026-03-08",
                totalTokens: 165,
                inputTokens: 120,
                outputTokens: 40,
                cacheReadTokens: 5
            ),
        ])
        #expect(snapshot.todayTokens == 165)
        #expect(snapshot.last7DaysTokens == 280)
        #expect(snapshot.last30DaysTokens == 280)
        #expect(snapshot.allDaysTokens == 280)
        #expect(snapshot.sourceLabel == "session")
    }

    @Test("Returns nil when no active Claude account exists")
    func fetchActiveSnapshot_returnsNilWithoutActiveAccount() async throws {
        let service = ClaudeTokenTrendService(
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

        let snapshot = try await service.fetchActiveSnapshot()
        #expect(snapshot == nil)
    }
}

private extension ClaudeTokenTrendServiceTests {
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
