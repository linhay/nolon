import XCTest
import ProviderCatalog
@testable import nolon

@MainActor
final class CodexRuntimeTabViewModelTests: XCTestCase {
    func testBDD_GivenRuntimeSnapshot_WhenRefreshing_ThenUpdatesProcessesAndDiagnostics() async {
        let provider = makeCodexProvider()
        let runtimeService = MockRuntimeService()
        runtimeService.runtimeListResult = .success([
            .init(
                pid: 101,
                ppid: 1,
                elapsed: "00:00:03",
                providerHint: "codex",
                command: "codex --version",
                workingDirectory: "/tmp/work-a"
            ),
            .init(
                pid: 202,
                ppid: 1,
                elapsed: "00:02:03",
                providerHint: "codex",
                command: "codex chat",
                workingDirectory: nil
            )
        ])
        runtimeService.diagnosticsResult = .success(
            .init(
                providerID: "codex",
                accountCount: 2,
                activeAccountID: "active",
                activeAccountName: "Lin",
                activeAccountEmail: "lin@company.com",
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
        XCTAssertEqual(viewModel.processes.first?.workingDirectory, "/tmp/work-a")
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

    func testBDD_GivenPollingEnabled_WhenRuntimeProcessesChange_ThenProcessesTrackAddRemove() async throws {
        let provider = makeCodexProvider()
        let runtimeService = MockRuntimeService()
        runtimeService.runtimeListResponses = [
            [.init(pid: 11, ppid: 1, elapsed: "00:01", providerHint: nil, command: "codex")],
            [
                .init(pid: 11, ppid: 1, elapsed: "00:02", providerHint: nil, command: "codex"),
                .init(pid: 22, ppid: 1, elapsed: "00:00", providerHint: nil, command: "codex new")
            ],
            [.init(pid: 22, ppid: 1, elapsed: "00:01", providerHint: nil, command: "codex new")]
        ]
        runtimeService.diagnosticsResult = .success(.empty(providerID: "codex"))

        let viewModel = CodexRuntimeTabViewModel(
            provider: provider,
            runtimeService: runtimeService,
            logService: MockLogService(),
            pollingIntervalNanoseconds: 20_000_000
        )
        await viewModel.refresh()
        XCTAssertEqual(viewModel.processes.map { $0.pid }, [Int32(11)])

        viewModel.startProcessPolling()
        try await Task.sleep(nanoseconds: 70_000_000)
        viewModel.stopProcessPolling()

        XCTAssertEqual(viewModel.processes.map { $0.pid }, [Int32(22)])
        XCTAssertGreaterThanOrEqual(runtimeService.runtimeListCallCount, 3)
    }

    func testBDD_GivenDiagnosticsAndProcess_WhenBuildingProcessDiagnosticRows_ThenIncludesExpectedFields() async {
        let provider = makeCodexProvider()
        let runtimeService = MockRuntimeService()
        runtimeService.runtimeListResult = .success([
            .init(pid: 101, ppid: 1, elapsed: "00:01", providerHint: "codex", command: "codex chat")
        ])
        runtimeService.diagnosticsResult = .success(
            .init(
                providerID: "codex",
                accountCount: 3,
                activeAccountID: "7F1A1234-ABCD-4321-9F00-111122229C2D",
                activeAccountName: "Lin",
                activeAccountEmail: "lin@company.com",
                selectedVersionID: "1.15.0",
                currentVersion: "1.15.0",
                pathActive: true,
                runtimeCount: 2,
                resolvedExecutable: "/usr/local/bin/codex",
                probeWarning: nil,
                probeHint: "ok"
            )
        )

        let viewModel = CodexRuntimeTabViewModel(provider: provider, runtimeService: runtimeService, logService: MockLogService())
        await viewModel.refresh()
        let rows = viewModel.processDiagnosticsRows(for: viewModel.processes[0])

        XCTAssertEqual(rows.count, 8)
        XCTAssertEqual(rows.first(where: { $0.key == .provider })?.value, "codex")
        XCTAssertEqual(rows.first(where: { $0.key == .accounts })?.value, "3")
        XCTAssertEqual(rows.first(where: { $0.key == .active })?.value, "Lin (lin@company.com) [id: 7F1A...9C2D]")
        XCTAssertEqual(rows.first(where: { $0.key == .running })?.value, "2")
        XCTAssertEqual(rows.first(where: { $0.key == .binary })?.value, "1.15.0")
        XCTAssertEqual(rows.first(where: { $0.key == .pathActive })?.value, "true")
        XCTAssertEqual(rows.first(where: { $0.key == .executable })?.value, "/usr/local/bin/codex")
        XCTAssertEqual(rows.first(where: { $0.key == .hint })?.value, "ok")
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
    var runtimeListResponses: [[CodexRuntimeProcessItem]] = []
    var runtimeListCallCount: Int = 0
    private var stickyRuntimeListResponse: [CodexRuntimeProcessItem]?
    var runtimeStopResult: Result<CodexRuntimeStopResult, Error> = .success(.init(pid: 0, requestedSignal: "term", didEscalateToKill: false, exited: true))
    var diagnosticsResult: Result<CodexRuntimeDiagnosticsSnapshot, Error> = .success(.empty(providerID: "codex"))
    var stopCalls: [(pid: Int32, force: Bool, timeoutSeconds: Int)] = []

    func runtimeList(providerID: String?) async throws -> [CodexRuntimeProcessItem] {
        _ = providerID
        runtimeListCallCount += 1
        if !runtimeListResponses.isEmpty {
            let next = runtimeListResponses.removeFirst()
            stickyRuntimeListResponse = next
            return next
        }
        if let stickyRuntimeListResponse {
            return stickyRuntimeListResponse
        }
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
