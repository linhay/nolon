import Foundation
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderCatalog
@testable import ProviderUsage
@testable import CodexProvider
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@Suite("Nolon Codex CLI Service")
struct NolonCodexCLIServiceTests {
    @Test("auth list canonicalizes codexxcode provider id")
    func authListCanonicalProviderID() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.authList(providerID: "codexxcode")
        #expect(payload.providerID == "codex-xcode")
    }

    @Test("status probe rejects unsupported provider in service")
    func statusProbeRejectsUnsupportedProvider() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        do {
            _ = try await service.statusProbe(providerID: "claude")
            Issue.record("Expected invalidArguments error")
        } catch let error as NolonCoreCLIError {
            guard case .invalidArguments = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("auth delete returns domain error when account is missing")
    func authDeleteMissingAccount() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        do {
            _ = try await service.authDelete(
                providerID: "codex",
                accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            )
            Issue.record("Expected codex_auth_account_not_found error")
        } catch let error as NolonCoreCLIError {
            guard case let .domainFailed(code, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(code == "codex_auth_account_not_found")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("auth list includes email usage display and refreshed time from local cache")
    func authListIncludesEmailUsageAndRefresh() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let authManager = CodexAuthManager(rootURL: root)
        let account = try await authManager.addAccount(
            name: "demo",
            authJSONString: #"{"user":{"email":"dev@example.com"}}"#
        )

        let cache = CodexAuthUsageCache(
            cachedAt: Date(timeIntervalSince1970: 1_733_000_000),
            creditsRefreshedAt: Date(timeIntervalSince1970: 1_734_000_000),
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: UsageSnapshot(
                identity: nil,
                primary: RateWindow(usedPercent: 17),
                secondary: RateWindow(usedPercent: 50),
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_733_500_000)
            ),
            credits: nil,
            cost: nil
        )
        try await authManager.storeUsageCache(cache, for: account)

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.authList(providerID: "codex")
        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].email == "dev@example.com")
        #expect(payload.accounts[0].usageDisplay == "5h 83% / 7d 50%")
        #expect(payload.accounts[0].refreshedAt == Date(timeIntervalSince1970: 1_734_000_000))
    }

    @Test("auth list usage display keeps slash-aligned template when only weekly window exists")
    func authListUsageDisplayWeeklyOnly() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let authManager = CodexAuthManager(rootURL: root)
        let account = try await authManager.addAccount(
            name: "demo",
            authJSONString: #"{"user":{"email":"weekly@example.com"}}"#
        )

        let cache = CodexAuthUsageCache(
            cachedAt: Date(timeIntervalSince1970: 1_733_000_000),
            creditsRefreshedAt: nil,
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: UsageSnapshot(
                identity: nil,
                primary: nil,
                secondary: RateWindow(usedPercent: 13.4),
                tertiary: nil,
                updatedAt: Date(timeIntervalSince1970: 1_733_500_000)
            ),
            credits: nil,
            cost: nil
        )
        try await authManager.storeUsageCache(cache, for: account)

        let service = NolonLiveCodexCLIService(
            authManager: authManager,
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.authList(providerID: "codex")
        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].usageDisplay == "5h - / 7d 87%")
        #expect(payload.accounts[0].refreshedAt == Date(timeIntervalSince1970: 1_733_500_000))
    }

    @Test("runtime list filters codex processes and sorts by pid asc")
    func runtimeListFiltersAndSorts() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:],
            runtimeProcessInspector: StubRuntimeProcessInspector(
                snapshots: [
                    NolonRuntimeProcessSnapshot(pid: 400, ppid: 1, elapsed: "00:00:05", command: "/bin/zsh"),
                    NolonRuntimeProcessSnapshot(pid: 220, ppid: 1, elapsed: "00:01:10", command: "/opt/homebrew/bin/codex"),
                    NolonRuntimeProcessSnapshot(pid: 180, ppid: 1, elapsed: "00:03:00", command: "/usr/local/bin/codex-app-server --provider codex-xcode"),
                    NolonRuntimeProcessSnapshot(pid: 181, ppid: 1, elapsed: "00:00:01", command: "/bin/zsh -lc nolon codex runtime list"),
                ]
            ),
            runtimeSignalController: StubRuntimeSignalController(),
            currentPIDProvider: { 999_999 },
            sleep: { _ in }
        )

        let payload = try await service.runtimeList(providerID: nil)
        #expect(payload.processes.map(\.pid) == [180, 220])
        #expect(payload.processes[0].providerHint == "codex-xcode")
        #expect(payload.processes[1].providerHint == "codex")
    }

    @Test("runtime stop escalates to kill when process does not exit after term")
    func runtimeStopEscalatesToKill() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let signalController = StubRuntimeSignalController(
            aliveSequenceByPID: [
                12345: Array(repeating: true, count: 20),
            ]
        )
        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:],
            runtimeProcessInspector: StubRuntimeProcessInspector(snapshots: []),
            runtimeSignalController: signalController,
            currentPIDProvider: { 999_999 },
            sleep: { _ in }
        )

        let payload = try await service.runtimeStop(pid: 12345, force: false, timeoutSeconds: 1)
        #expect(payload.requestedSignal == "term")
        #expect(payload.didEscalateToKill == true)
        #expect(payload.exited == true)
        #expect(signalController.signals.map(\.pid) == [12345, 12345])
        #expect(signalController.signals.map(\.signal) == [SIGTERM, SIGKILL])
    }

    @Test("provider discover returns codex providers and auth symlink state")
    func providerDiscoverReturnsCodexProviders() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-provider-discover-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.providerDiscover()
        #expect(payload.providers.map(\.providerID) == ["codex", "codex-xcode"])
        #expect(payload.providers.count == 2)
        #expect(payload.providers.first?.providerID == "codex")
        #expect(payload.providers.last?.providerID == "codex-xcode")
        #expect(payload.providers.first?.authPath.isEmpty == false)
    }

    @Test("provider list returns installed providers only")
    func providerListReturnsInstalledOnly() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-provider-list-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.providerList()
        #expect(payload.providers.allSatisfy { $0.installed })
        #expect(payload.providers.allSatisfy { !($0.executablePath?.isEmpty ?? true) })
        let expectedCLIByProviderID = Dictionary(
            uniqueKeysWithValues: ProviderTemplate.allCases.map { ($0.providerID, $0.cliName) }
        )
        #expect(payload.providers.allSatisfy { expectedCLIByProviderID[$0.providerID] == $0.cli })
    }
}

private struct StubRuntimeProcessInspector: NolonCodexRuntimeProcessInspecting {
    let snapshots: [NolonRuntimeProcessSnapshot]

    func listProcesses() throws -> [NolonRuntimeProcessSnapshot] {
        snapshots
    }
}

private struct SentSignal: Equatable {
    let pid: Int32
    let signal: Int32
}

private final class StubRuntimeSignalController: NolonCodexRuntimeSignalControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var signalStorage: [SentSignal] = []
    private var aliveSequences: [Int32: [Bool]]
    private var killedPIDs: Set<Int32> = []

    init(aliveSequenceByPID: [Int32: [Bool]] = [:]) {
        self.aliveSequences = aliveSequenceByPID
    }

    var signals: [SentSignal] {
        lock.lock()
        defer { lock.unlock() }
        return signalStorage
    }

    func send(signal: Int32, to pid: Int32) throws {
        lock.lock()
        defer { lock.unlock() }
        signalStorage.append(SentSignal(pid: pid, signal: signal))
        if signal == SIGKILL {
            killedPIDs.insert(pid)
            aliveSequences[pid] = [false]
        }
    }

    func isRunning(pid: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard var sequence = aliveSequences[pid] else {
            return false
        }
        guard !sequence.isEmpty else {
            if killedPIDs.contains(pid) {
                return false
            }
            return true
        }
        let current = sequence.removeFirst()
        aliveSequences[pid] = sequence
        return current
    }
}
