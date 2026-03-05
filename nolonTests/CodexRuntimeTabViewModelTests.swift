import XCTest
import ProviderCatalog
@testable import nolon

@MainActor
final class CodexRuntimeTabViewModelTests: XCTestCase {
    func testBDD_GivenRuntimeSnapshot_WhenRefreshing_ThenUpdatesProcessesAndDiagnostics() async {
        let provider = makeCodexProvider()
        let runtimeService = MockRuntimeService()
        runtimeService.runtimeListResult = .success([
            .init(pid: 101, ppid: 1, elapsed: "00:00:03", providerHint: "codex", command: "codex --version"),
            .init(pid: 202, ppid: 1, elapsed: "00:02:03", providerHint: "codex", command: "codex chat")
        ])
        runtimeService.diagnosticsResult = .success(
            .init(
                providerID: "codex",
                accountCount: 2,
                activeAccountID: "active",
                selectedVersionID: "1.0.0",
                currentVersion: "1.0.0",
                pathActive: true,
                runtimeCount: 2,
                resolvedExecutable: "/usr/local/bin/codex",
                probeWarning: nil,
                probeHint: nil
            )
        )
        let logs = MockLogService()
        logs.result = .success("line-a\nline-b")

        let viewModel = CodexRuntimeTabViewModel(provider: provider, runtimeService: runtimeService, logService: logs)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.processes.count, 2)
        XCTAssertEqual(viewModel.processes.map(\.pid), [101, 202])
        XCTAssertEqual(viewModel.selectedPID, 101)
        XCTAssertEqual(viewModel.diagnostics?.accountCount, 2)
        XCTAssertEqual(viewModel.logsText, "line-a\nline-b")
        XCTAssertNil(viewModel.alertMessage)
    }

    func testBDD_GivenStopSuccess_WhenStoppingPID_ThenRefreshesAndUpdatesSummary() async {
        let provider = makeCodexProvider()
        let runtimeService = MockRuntimeService()
        runtimeService.runtimeListResult = .success([.init(pid: 42, ppid: 1, elapsed: "00:01", providerHint: nil, command: "codex")])
        runtimeService.diagnosticsResult = .success(.empty(providerID: "codex"))
        runtimeService.runtimeStopResult = .success(.init(pid: 42, requestedSignal: "term", didEscalateToKill: false, exited: true))

        let viewModel = CodexRuntimeTabViewModel(provider: provider, runtimeService: runtimeService, logService: MockLogService())
        await viewModel.refresh()

        runtimeService.runtimeListResult = .success([])
        await viewModel.stop(pid: 42, force: false)

        XCTAssertEqual(runtimeService.stopCalls.count, 1)
        XCTAssertEqual(runtimeService.stopCalls.first?.pid, 42)
        XCTAssertEqual(runtimeService.stopCalls.first?.force, false)
        XCTAssertEqual(viewModel.processes.count, 0)
        XCTAssertTrue(viewModel.lastStopMessage?.contains("42") == true)
    }

    func testBDD_GivenStopFailure_WhenStoppingPID_ThenShowsStructuredError() async {
        let provider = makeCodexProvider()
        let runtimeService = MockRuntimeService()
        runtimeService.runtimeListResult = .success([.init(pid: 55, ppid: 1, elapsed: "00:01", providerHint: nil, command: "codex")])
        runtimeService.diagnosticsResult = .success(.empty(providerID: "codex"))
        runtimeService.runtimeStopResult = .failure(MockError(message: "permission denied"))

        let viewModel = CodexRuntimeTabViewModel(provider: provider, runtimeService: runtimeService, logService: MockLogService())
        await viewModel.refresh()
        await viewModel.stop(pid: 55, force: false)

        XCTAssertNotNil(viewModel.alertMessage)
        XCTAssertTrue(viewModel.alertMessage?.contains("permission denied") == true)
    }

    func testBDD_GivenForceStopConfirmation_WhenConfirming_ThenRunsForceStop() async {
        let provider = makeCodexProvider()
        let runtimeService = MockRuntimeService()
        runtimeService.runtimeListResult = .success([.init(pid: 66, ppid: 1, elapsed: "00:01", providerHint: nil, command: "codex")])
        runtimeService.diagnosticsResult = .success(.empty(providerID: "codex"))
        runtimeService.runtimeStopResult = .success(.init(pid: 66, requestedSignal: "kill", didEscalateToKill: false, exited: true))

        let viewModel = CodexRuntimeTabViewModel(provider: provider, runtimeService: runtimeService, logService: MockLogService())
        await viewModel.refresh()
        viewModel.requestForceStop(pid: 66)
        await viewModel.confirmForceStop()

        XCTAssertNil(viewModel.pendingForceStopPID)
        XCTAssertEqual(runtimeService.stopCalls.first?.force, true)
    }

    func testBDD_GivenSelectedPID_WhenRefreshingLogsFails_ThenOnlyLogsAreaShowsError() async {
        let provider = makeCodexProvider()
        let runtimeService = MockRuntimeService()
        runtimeService.runtimeListResult = .success([.init(pid: 88, ppid: 1, elapsed: "00:01", providerHint: nil, command: "codex")])
        runtimeService.diagnosticsResult = .success(.empty(providerID: "codex"))

        let logs = MockLogService()
        logs.result = .failure(MockError(message: "log unavailable"))

        let viewModel = CodexRuntimeTabViewModel(provider: provider, runtimeService: runtimeService, logService: logs)
        await viewModel.refresh()

        XCTAssertEqual(viewModel.processes.count, 1)
        XCTAssertEqual(viewModel.selectedPID, 88)
        XCTAssertTrue(viewModel.logsErrorMessage?.contains("log unavailable") == true)
        XCTAssertNil(viewModel.alertMessage)
    }

    private func makeCodexProvider() -> Provider {
        Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
    }
}

private final class MockRuntimeService: CodexRuntimeTabServicing {
    var runtimeListResult: Result<[CodexRuntimeProcessItem], Error> = .success([])
    var runtimeStopResult: Result<CodexRuntimeStopResult, Error> = .success(.init(pid: 0, requestedSignal: "term", didEscalateToKill: false, exited: true))
    var diagnosticsResult: Result<CodexRuntimeDiagnosticsSnapshot, Error> = .success(.empty(providerID: "codex"))
    var stopCalls: [(pid: Int32, force: Bool, timeoutSeconds: Int)] = []

    func runtimeList(providerID: String?) async throws -> [CodexRuntimeProcessItem] {
        _ = providerID
        return try runtimeListResult.get()
    }

    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> CodexRuntimeStopResult {
        stopCalls.append((pid, force, timeoutSeconds))
        return try runtimeStopResult.get()
    }

    func diagnostics(providerID: String) async throws -> CodexRuntimeDiagnosticsSnapshot {
        _ = providerID
        return try diagnosticsResult.get()
    }
}

private final class MockLogService: CodexPIDSystemLogServicing {
    var result: Result<String, Error> = .success("")

    func fetchLogs(pid: Int32, lastSeconds: Int, maxLines: Int) async throws -> String {
        _ = pid
        _ = lastSeconds
        _ = maxLines
        return try result.get()
    }
}

private struct MockError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
