import Foundation
import Testing
import ProvidersShared
@testable import CodexProvider

@Suite("CodexStatusProbe")
struct CodexStatusProbeTests {
    actor ProbeCallCounter {
        private(set) var primaryCalls: Int = 0
        private(set) var fallbackCalls: Int = 0

        func markPrimary() {
            primaryCalls += 1
        }

        func markFallback() {
            fallbackCalls += 1
        }
    }

    struct MockRunner: CodexCLICommandRunning {
        let runBlock: @Sendable (_ binary: String, _ send: String, _ options: TTYCommandRunner.Options) async throws -> TTYCommandRunner.Result

        func run(binary: String, send: String, options: TTYCommandRunner.Options) async throws -> TTYCommandRunner.Result {
            try await runBlock(binary, send, options)
        }
    }

    @Test("Given parse failure, when fetching status, then do not fallback to interactive runner")
    func givenParseFailureWhenFetchingStatusThenNoFallbackRunner() async {
        let counter = ProbeCallCounter()

        let primary = MockRunner { _, _, _ in
            await counter.markPrimary()
            return TTYCommandRunner.Result(text: "unparseable status output")
        }

        let fallback = MockRunner { _, _, _ in
            await counter.markFallback()
            return TTYCommandRunner.Result(text: "Credits: 123")
        }

        let probe = CodexStatusProbe(
            codexBinary: "/bin/echo",
            timeout: 0.1,
            environment: ProcessInfo.processInfo.environment,
            runner: primary,
            fallbackRunner: fallback
        )

        do {
            _ = try await probe.fetch()
            Issue.record("Expected parse failure without fallback runner")
        } catch let error as CodexStatusProbeError {
            switch error {
            case .parseFailed:
                break
            default:
                Issue.record("Expected parseFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected CodexStatusProbeError.parseFailed, got \(error)")
        }

        let primaryCalls = await counter.primaryCalls
        let fallbackCalls = await counter.fallbackCalls
        #expect(primaryCalls == 2)
        #expect(fallbackCalls == 0)
    }
}
