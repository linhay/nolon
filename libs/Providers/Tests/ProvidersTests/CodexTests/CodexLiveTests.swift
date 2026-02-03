import Foundation
import Providers
import SKProcessRunner
import Testing

@Suite("Codex (Live)")
struct CodexLiveTests {
    private var env: [String: String] {
        let processEnv = ProcessInfo.processInfo.environment
        let shellEnv = SKProcessRunner.loadUserShellEnvironmentSync(environment: processEnv)
        var merged = processEnv.merging(shellEnv, uniquingKeysWith: { _, shell in shell })
        if merged["PATH"]?.isEmpty != false, let shellPATH = SKProcessRunner.loadUserShellPATHSync(environment: processEnv) {
            merged["PATH"] = shellPATH
        }
        return merged
    }

    @Test("Fetch rate limits via RPC")
    func fetchRateLimits_live() async throws {
        let helper = CodexHelper(environment: env)
        guard helper.isCLIAvailable else { return }

        let snapshot = try await helper.fetchRateLimits()
        #expect(snapshot.primary != nil || snapshot.secondary != nil)

        if let primary = snapshot.primary {
            #expect(primary.usedPercent >= 0)
            #expect(primary.usedPercent <= 100)
        }
        if let secondary = snapshot.secondary {
            #expect(secondary.usedPercent >= 0)
            #expect(secondary.usedPercent <= 100)
        }
    }

    @Test("Fetch credits (best-effort)")
    func fetchCredits_live() async throws {
        let helper = CodexHelper(environment: env)
        guard helper.isCLIAvailable else { return }

        let fetcher = CodexCreditsFetcher(environment: env)
        let snapshot = try await fetcher.fetchCredits(keepCLISessionsAlive: false)
        #expect(snapshot.remaining.isInfinite || snapshot.remaining.isNaN || snapshot.remaining >= 0)
    }
}
