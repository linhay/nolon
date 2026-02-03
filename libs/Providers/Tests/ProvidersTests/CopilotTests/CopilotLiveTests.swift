import Foundation
import Providers
import SKProcessRunner
import Testing

@Suite("Copilot (Live)")
struct CopilotLiveTests {
    private var env: [String: String] {
        let processEnv = ProcessInfo.processInfo.environment
        let shellEnv = SKProcessRunner.loadUserShellEnvironmentSync(environment: processEnv)
        var merged = processEnv.merging(shellEnv, uniquingKeysWith: { _, shell in shell })
        if merged["PATH"]?.isEmpty != false, let shellPATH = SKProcessRunner.loadUserShellPATHSync(environment: processEnv) {
            merged["PATH"] = shellPATH
        }
        return merged
    }

    @Test("Fetch usage from GitHub API")
    func fetchUsage_live() async throws {
        guard env["RUN_LIVE_PROVIDER_TESTS"] == "1" else { return }
        guard env["COPILOT_API_TOKEN"]?.isEmpty == false else { return }

        let helper = CopilotHelper(environment: env)
        let snapshot = try await helper.fetchUsage()
        #expect(snapshot.plan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }
}
