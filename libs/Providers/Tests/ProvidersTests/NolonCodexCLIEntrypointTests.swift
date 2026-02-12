import Foundation
import Testing
@testable import NolonCoreCLIKit

@Suite("Nolon Codex CLI Entrypoint")
struct NolonCodexCLIEntrypointTests {
    @Test("routes auth list")
    func routesAuthList() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "list",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"codex.auth.list\""))
        #expect(await mock.lastCall() == "authList")
    }

    @Test("normalizes codexxcode provider alias")
    func normalizesCodexXcodeProviderAlias() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "list",
                "--provider", "codexxcode",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"providerID\":\"codex-xcode\""))
    }

    @Test("auth list rejects unsupported provider")
    func authListRejectsUnsupportedProvider() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "list",
                "--provider", "claude",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("routes auth status")
    func routesAuthStatus() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "status",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"codex.auth.status\""))
        #expect(await mock.lastCall() == "authStatus")
    }

    @Test("auth status rejects unsupported provider")
    func authStatusRejectsUnsupportedProvider() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "status",
                "--provider", "cursor",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("routes auth activate via argument parser")
    func routesAuthActivate() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--provider", "codex",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"codex.auth.activate\""))
        #expect(result.stderr.isEmpty)
        #expect(await mock.lastCall() == "authActivate")
    }

    @Test("invalid UUID returns structured error")
    func invalidUUIDError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--account-id", "not-a-uuid",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("invalid preferred account UUID returns structured error")
    func invalidPreferredUUIDError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "login",
                "--preferred-account-id", "bad-uuid",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("routes auth login")
    func routesAuthLogin() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "login",
                "--provider", "codex",
                "--preferred-account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"codex.auth.login\""))
        #expect(await mock.lastCall() == "authLogin")
    }

    @Test("routes binary install set-default")
    func routesBinaryInstall() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "install",
                "--version", "0.26.0",
                "--set-default",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"codex.binary.install\""))
        #expect(await mock.lastCall() == "binaryInstall")
    }

    @Test("routes binary current")
    func routesBinaryCurrent() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "current",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"codex.binary.current\""))
        #expect(await mock.lastCall() == "binaryCurrent")
    }

    @Test("routes binary use")
    func routesBinaryUse() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "use",
                "--version", "0.26.0",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"codex.binary.use\""))
        #expect(await mock.lastCall() == "binaryUse")
    }

    @Test("routes binary doctor")
    func routesBinaryDoctor() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "doctor",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"codex.binary.doctor\""))
        #expect(await mock.lastCall() == "binaryDoctor")
    }

    @Test("routes status probe")
    func routesStatusProbe() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "probe",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"codex.status.probe\""))
        #expect(await mock.lastCall() == "statusProbe")
    }

    @Test("normalizes provider alias in status probe")
    func normalizesProviderAliasInStatusProbe() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "probe",
                "--provider", "codexxcode",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"providerID\":\"codex-xcode\""))
    }

    @Test("status probe rejects unsupported provider")
    func statusProbeRejectsUnsupportedProvider() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "probe",
                "--provider", "claude",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("unsupported command returns invalid arguments")
    func unsupportedCommandError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "unknown",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("domain error keeps structured code")
    func domainErrorCode() async {
        let mock = DomainErrorCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "use",
                "--version", "missing",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"codex_binary_not_found\""))
    }
}

private actor MockCodexCLIService: NolonCodexCLIServing {
    private var call: String?

    func lastCall() -> String? { call }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        call = "authList"
        return NolonCodexAuthListPayload(providerID: providerID, activeAccountID: nil, accounts: [])
    }

    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        call = "authStatus"
        return NolonCodexAuthStatusPayload(providerID: providerID, activeAccountID: nil, accountCount: 0, authHashHex: nil)
    }

    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        call = "authActivate"
        return NolonCodexAuthActivatePayload(
            providerID: providerID,
            accountID: accountID,
            runtimeSwitched: true,
            runtimeErrorDescription: nil
        )
    }

    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        call = "authLogin"
        return NolonCodexAuthLoginPayload(
            providerID: providerID,
            accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            accountName: "mock",
            runtimeSwitched: true,
            runtimeErrorDescription: nil
        )
    }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        call = "binaryList"
        return NolonCodexBinaryListPayload(selectedVersionID: nil, versions: [])
    }

    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload {
        call = "binaryCurrent"
        return NolonCodexBinaryCurrentPayload(selectedVersionID: nil, currentVersion: nil, activeCLIPath: nil)
    }

    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload {
        call = "binaryInstall"
        return NolonCodexBinaryInstallPayload(
            requestedVersion: version,
            installedVersionID: "v\(version)-mock",
            installedDetectedVersion: version,
            activated: setDefault
        )
    }

    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload {
        call = "binaryUse"
        return NolonCodexBinaryUsePayload(selectedVersionID: version)
    }

    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload {
        call = "binaryDoctor"
        return NolonCodexBinaryDoctorPayload(
            selectedVersionID: nil,
            currentVersion: nil,
            activeCLIPath: nil,
            managedVersionCount: 0,
            pathConfigured: false,
            pathActive: false,
            profilePath: "~/.zshrc"
        )
    }

    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload {
        call = "statusProbe"
        return NolonCodexStatusProbePayload(
            providerID: providerID,
            resolvedExecutable: "/opt/homebrew/bin/codex",
            credits: nil,
            fiveHourPercentLeft: nil,
            weeklyPercentLeft: nil,
            fiveHourResetDescription: nil,
            weeklyResetDescription: nil
        )
    }
}

private actor DomainErrorCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw makeError() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw makeError() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw makeError() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw makeError() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw makeError() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw makeError() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw makeError() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw makeError() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw makeError() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw makeError() }

    private func makeError() -> NolonCoreCLIError {
        .domainFailed(code: "codex_binary_not_found", message: "missing")
    }
}
