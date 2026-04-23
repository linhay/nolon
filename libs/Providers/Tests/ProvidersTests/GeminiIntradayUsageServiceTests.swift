import Foundation
import Testing
@testable import ProviderUsage

@Suite("GeminiIntradayUsageService")
struct GeminiIntradayUsageServiceTests {
    @Test("Aggregates selected Gemini day into 30min buckets with DST-aware bucket count")
    func fetchActiveSnapshot_aggregatesSelectedDayIntoDSTBuckets() async throws {
        let globalGeminiURL = URL(fileURLWithPath: "/Users/tester/.gemini", isDirectory: true)
        let timezone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let referenceDate = try #require(
            Calendar(identifier: .gregorian).date(from: DateComponents(
                timeZone: TimeZone(secondsFromGMT: 0),
                year: 2026,
                month: 3,
                day: 9,
                hour: 12,
                minute: 0
            ))
        )
        let service = GeminiIntradayUsageService(
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
            listSessionFiles: { _ in
                [globalGeminiURL.appendingPathComponent("tmp/project-a/chats/session-1.json")]
            },
            readFile: { _ in
                """
                {
                  "messages": [
                    {
                      "type": "gemini",
                      "timestamp": "2026-03-08T09:10:00Z",
                      "tokens": { "input": 100, "output": 40, "cached": 20, "total": 140 }
                    },
                    {
                      "type": "gemini",
                      "timestamp": "2026-03-08T10:10:00Z",
                      "tokens": { "input": 60, "output": 30, "cached": 10, "total": 90 }
                    },
                    {
                      "type": "gemini",
                      "timestamp": "2026-03-09T08:10:00Z",
                      "tokens": { "input": 999, "output": 1, "cached": 0, "total": 1000 }
                    }
                  ]
                }
                """
            },
            now: { referenceDate }
        )

        let snapshot = try #require(
            await service.fetchActiveSnapshot(
                provider: .gemini,
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
        #expect(snapshot.points.reduce(0) { $0 + $1.totalTokens } == 230)
        #expect(snapshot.points[0].totalTokens == 140)
        #expect(snapshot.points[0].requestCount == 1)
        #expect(snapshot.points[1].totalTokens == 90)
        #expect(snapshot.points[1].requestCount == 1)
        #expect(snapshot.sourceLabel == "session")
    }

    @Test("Returns nil when no active Gemini account exists")
    func fetchActiveSnapshot_returnsNilWithoutActiveAccount() async throws {
        let service = GeminiIntradayUsageService(
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

        let snapshot = try await service.fetchActiveSnapshot(
            provider: .gemini,
            dayKey: "2026-03-08",
            bucket: .minute15
        )
        #expect(snapshot == nil)
    }
}
