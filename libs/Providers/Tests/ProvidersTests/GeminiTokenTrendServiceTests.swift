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
            now: {
                Date(timeIntervalSince1970: 1_709_900_000)
            }
        )

        let snapshot = try #require(await service.fetchActiveSnapshot(provider: .gemini))

        #expect(snapshot.points == [
            ProviderTokenTrendPoint(
                date: "2026-03-07",
                totalTokens: 110,
                inputTokens: 80,
                outputTokens: 30,
                cacheReadTokens: 5
            ),
            ProviderTokenTrendPoint(
                date: "2026-03-08",
                totalTokens: 220,
                inputTokens: 160,
                outputTokens: 60,
                cacheReadTokens: 35
            ),
        ])
        #expect(snapshot.todayTokens == 220)
        #expect(snapshot.last7DaysTokens == 330)
        #expect(snapshot.last30DaysTokens == 330)
        #expect(snapshot.allDaysTokens == 330)
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
            now: { Date(timeIntervalSince1970: 1_709_900_000) }
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
            now: { Date(timeIntervalSince1970: 1_709_900_000) }
        )

        let snapshot = try #require(await service.fetchActiveSnapshot(provider: .gemini))

        #expect(snapshot.points == [
            ProviderTokenTrendPoint(
                date: "2026-03-08",
                totalTokens: 150,
                inputTokens: 120,
                outputTokens: 30,
                cacheReadTokens: 10
            ),
        ])
        #expect(snapshot.todayTokens == 150)
        #expect(snapshot.last7DaysTokens == 150)
        #expect(snapshot.last30DaysTokens == 150)
        #expect(snapshot.allDaysTokens == 150)
    }
}
