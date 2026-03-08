import Foundation
import Testing
@testable import ProviderUsage

@Suite("GeminiQuotaFetcher")
struct GeminiQuotaFetcherTests {
    @Test("Parses OAuth quota buckets into Pro and Flash windows")
    func fetch_parsesQuotaBuckets() async throws {
        let now = Date(timeIntervalSince1970: 1_715_400_000)
        let fetcher = GeminiQuotaFetcher(
            resolveExecutable: { binary, _ in
                switch binary {
                case "gemini":
                    return URL(fileURLWithPath: "/opt/homebrew/lib/node_modules/@google/gemini-cli/dist/index.js")
                case "node":
                    return URL(fileURLWithPath: "/opt/homebrew/bin/node")
                default:
                    throw GeminiQuotaFetchError.binaryNotFound(binary)
                }
            },
            runNodeScript: { _, _, environment in
                #expect(environment["GEMINI_CLI_HOME"] == "/tmp/runtime-home")
                #expect(environment["GOOGLE_GENAI_USE_GCA"] == "true")
                return """
                {"projectId":"proj","quota":{"buckets":[
                  {"modelId":"gemini-2.0-flash","remainingFraction":0.75,"resetTime":"2026-03-08T12:00:00Z"},
                  {"modelId":"gemini-2.5-flash","remainingFraction":0.8,"resetTime":"2026-03-08T13:00:00Z"},
                  {"modelId":"gemini-3.1-pro-preview","remainingFraction":0.94,"resetTime":"2026-03-08T14:00:00Z"}
                ]}}
                """
            },
            fileExists: { path in
                path == "/opt/homebrew/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/index.js"
            },
            now: { now }
        )
        let account = GeminiAuthAccount(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            providerID: .gemini,
            name: "Gemini",
            method: .oauthPersonal,
            createdAt: now,
            lastUsedAt: now,
            lastLoginAt: now,
            email: "dev@example.com",
            project: nil,
            location: nil,
            runtimeHomeRelativePath: "accounts/runtime/home"
        )

        let snapshot = try #require(await fetcher.fetch(
            account: account,
            runtimeHomeURL: URL(fileURLWithPath: "/tmp/runtime-home", isDirectory: true),
            environment: [:]
        ))

        #expect(snapshot.fetchedAt == now)
        #expect(snapshot.pro?.modelID == "gemini-3.1-pro-preview")
        #expect(snapshot.flash?.modelID == "gemini-2.5-flash")
        #expect(snapshot.buckets.map(\.modelID) == [
            "gemini-2.0-flash",
            "gemini-2.5-flash",
            "gemini-3.1-pro-preview",
        ])
    }

    @Test("Ignores non JSON log lines before quota payload")
    func fetch_parsesQuotaBucketsWithPrefixedLogs() async throws {
        let now = Date(timeIntervalSince1970: 1_715_400_100)
        let fetcher = GeminiQuotaFetcher(
            resolveExecutable: { binary, _ in
                switch binary {
                case "gemini":
                    return URL(fileURLWithPath: "/opt/homebrew/lib/node_modules/@google/gemini-cli/dist/index.js")
                case "node":
                    return URL(fileURLWithPath: "/opt/homebrew/bin/node")
                default:
                    throw GeminiQuotaFetchError.binaryNotFound(binary)
                }
            },
            runNodeScript: { _, _, _ in
                """
                Loaded cached credentials.
                {\"projectId\":\"proj\",\"quota\":{\"buckets\":[
                  {\"modelId\":\"gemini-3-flash-preview\",\"remainingFraction\":0.81,\"resetTime\":\"2026-03-08T13:00:00Z\"},
                  {\"modelId\":\"gemini-3.1-pro-preview\",\"remainingFraction\":0.93,\"resetTime\":\"2026-03-08T14:00:00Z\"}
                ]}}
                """
            },
            fileExists: { path in
                path == "/opt/homebrew/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/index.js"
            },
            now: { now }
        )
        let account = GeminiAuthAccount(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            providerID: .gemini,
            name: "Gemini",
            method: .oauthPersonal,
            createdAt: now,
            lastUsedAt: now,
            lastLoginAt: now,
            email: "dev@example.com",
            project: nil,
            location: nil,
            runtimeHomeRelativePath: "accounts/runtime/home"
        )

        let snapshot = try #require(await fetcher.fetch(
            account: account,
            runtimeHomeURL: URL(fileURLWithPath: "/tmp/runtime-home", isDirectory: true),
            environment: [:]
        ))

        #expect(snapshot.pro?.modelID == "gemini-3.1-pro-preview")
        #expect(snapshot.flash?.modelID == "gemini-3-flash-preview")
    }

    @Test("Skips quota fetch for non OAuth Gemini auth methods")
    func fetch_skipsNonOAuthMethods() async throws {
        let fetcher = GeminiQuotaFetcher(
            resolveExecutable: { _, _ in
                Issue.record("Non OAuth fetch should not resolve executables")
                return URL(fileURLWithPath: "/tmp/unused")
            },
            runNodeScript: { _, _, _ in
                Issue.record("Non OAuth fetch should not run node")
                return "{}"
            }
        )
        let account = GeminiAuthAccount(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            providerID: .gemini,
            name: "Gemini API",
            method: .geminiAPIKey,
            createdAt: Date(timeIntervalSince1970: 1_715_400_000),
            lastUsedAt: nil,
            lastLoginAt: nil,
            email: nil,
            project: nil,
            location: nil,
            runtimeHomeRelativePath: "accounts/runtime/home"
        )

        let snapshot = try await fetcher.fetch(
            account: account,
            runtimeHomeURL: URL(fileURLWithPath: "/tmp/runtime-home", isDirectory: true),
            environment: [:]
        )

        #expect(snapshot == nil)
    }
}
