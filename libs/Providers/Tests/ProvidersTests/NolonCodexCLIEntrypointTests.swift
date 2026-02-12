import Foundation
import Testing
@testable import NolonCoreCLIKit

@Suite("Nolon Codex CLI Entrypoint")
struct NolonCodexCLIEntrypointTests {
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
