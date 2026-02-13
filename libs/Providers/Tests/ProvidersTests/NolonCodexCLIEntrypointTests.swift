import Foundation
import Testing
@testable import NolonCoreCLIKit

@Suite("Nolon Codex CLI Entrypoint")
struct NolonCodexCLIEntrypointTests {
    @Test("no arguments prints help instead of JSON error")
    func noArgumentsPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(arguments: [], codexService: mock)

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex <group> <action>"))
        #expect(result.stdout.contains("nolon codex auth list"))
    }

    @Test("codex --help prints codex help")
    func codexHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex <group> <action>"))
        #expect(result.stdout.contains("Groups:"))
    }

    @Test("codex without group action prints codex help")
    func codexWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex <group> <action>"))
    }

    @Test("codex auth --help prints auth help")
    func codexAuthHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth <action>"))
        #expect(result.stdout.contains("Actions:"))
    }

    @Test("codex auth without action prints auth help")
    func codexAuthWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth <action>"))
    }

    @Test("codex binary --help prints binary help")
    func codexBinaryHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary <action>"))
        #expect(result.stdout.contains("install  --version"))
    }

    @Test("codex binary without action prints binary help")
    func codexBinaryWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary <action>"))
    }

    @Test("codex status --help prints status help")
    func codexStatusHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status <action>"))
        #expect(result.stdout.contains("probe"))
    }

    @Test("codex status without action prints status help")
    func codexStatusWithoutActionPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status <action>"))
    }

    @Test("codex runtime --help prints runtime help")
    func codexRuntimeHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex runtime <action>"))
        #expect(result.stdout.contains("list"))
        #expect(result.stdout.contains("stop"))
    }

    @Test("codex runtime list --help prints action help")
    func codexRuntimeListHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "list", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex runtime list"))
    }

    @Test("codex runtime stop --help prints action help")
    func codexRuntimeStopHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "stop", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex runtime stop"))
        #expect(result.stdout.contains("--pid"))
    }

    @Test("codex auth list --help prints action help")
    func codexAuthListHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "list", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth list"))
        #expect(result.stdout.contains("--provider"))
    }

    @Test("codex auth status --help prints action help")
    func codexAuthStatusHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "status", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth status"))
        #expect(result.stdout.contains("--provider"))
    }

    @Test("codex auth activate --help prints action help")
    func codexAuthActivateHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "activate", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth activate"))
        #expect(result.stdout.contains("--account-id"))
    }

    @Test("codex auth login --help prints action help")
    func codexAuthLoginHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "login", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth login"))
        #expect(result.stdout.contains("--preferred-account-id"))
    }

    @Test("codex auth delete --help prints action help")
    func codexAuthDeleteHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "delete", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex auth delete"))
        #expect(result.stdout.contains("--account-id"))
    }

    @Test("codex binary install --help prints action help")
    func codexBinaryInstallHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "install", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary install"))
        #expect(result.stdout.contains("--version"))
    }

    @Test("codex binary use --help prints action help")
    func codexBinaryUseHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "use", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary use"))
        #expect(result.stdout.contains("--version"))
    }

    @Test("codex binary list --help prints action help")
    func codexBinaryListHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "list", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary list"))
    }

    @Test("codex binary current --help prints action help")
    func codexBinaryCurrentHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "current", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary current"))
    }

    @Test("codex binary doctor --help prints action help")
    func codexBinaryDoctorHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "doctor", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex binary doctor"))
    }

    @Test("codex status probe --help prints action help")
    func codexStatusProbeHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "probe", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status probe"))
        #expect(result.stdout.contains("--provider"))
    }

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
        #expect(result.stdout.contains("邮箱"))
        #expect(result.stdout.contains("状态"))
        #expect(result.stdout.contains("用量"))
        #expect(result.stdout.contains("刷新时间"))
        #expect(await mock.lastCall() == "authList")
    }

    @Test("auth list prints aligned table rows")
    func authListPrintsAlignedTableRows() async {
        let service = AuthListTableCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "list", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        let lines = result.stdout.split(separator: "\n").map(String.init)
        #expect(lines.first?.contains("邮箱") == true)
        let rows = lines.dropFirst().filter { $0.hasPrefix("* ") || ($0.hasPrefix("  ") && $0.contains(" | ")) }
        #expect(rows.count == 2)
        let firstPipeIndices = rows[0].indicesOfPipes()
        #expect(firstPipeIndices.count == 3)
        #expect(rows[1].indicesOfPipes() == firstPipeIndices)
    }

    @Test("auth list shows dash when email usage refresh are missing")
    func authListShowsDashForMissingFields() async {
        let service = AuthListMissingFieldsCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "list", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("| -"))
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
        #expect(result.stdout.contains("邮箱"))
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
        #expect(result.stdout.contains("account_count: 0"))
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
        #expect(result.stdout.contains("runtime_switched: true"))
        #expect(result.stderr.isEmpty)
        #expect(await mock.lastCall() == "authActivate")
    }

    @Test("auth activate supports tui selection by index")
    func authActivateSupportsTUISelection() async throws {
        let accounts: [NolonCodexAuthAccountView] = [
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "A",
                createdAt: .distantPast,
                relativeAuthPath: "a/auth.json",
                isActive: true,
                email: "a@example.com",
                usageDisplay: nil,
                refreshedAt: nil
            ),
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                name: "B",
                createdAt: .distantPast,
                relativeAuthPath: "b/auth.json",
                isActive: false,
                email: "b@example.com",
                usageDisplay: nil,
                refreshedAt: nil
            ),
        ]

        let selected = try NolonCodexCLIExecutor.parseActivateSelection(
            input: "2",
            accounts: accounts
        )
        #expect(selected == UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!)
    }

    @Test("auth activate tui selection rejects invalid index")
    func authActivateTUISelectionRejectsInvalidIndex() {
        let accounts: [NolonCodexAuthAccountView] = [
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "A",
                createdAt: .distantPast,
                relativeAuthPath: "a/auth.json",
                isActive: true,
                email: "a@example.com",
                usageDisplay: nil,
                refreshedAt: nil
            ),
        ]

        #expect(throws: NolonCoreCLIError.invalidArguments("Invalid selection")) {
            _ = try NolonCodexCLIExecutor.parseActivateSelection(input: "3", accounts: accounts)
        }
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
        #expect(result.stdout.contains("account_name: mock"))
        #expect(result.stdout.contains("login_url: https://auth.example.com/device"))
        #expect(await mock.lastCall() == "authLogin")
    }

    @Test("routes auth delete")
    func routesAuthDelete() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "delete",
                "--provider", "codex",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("was_active: false"))
        #expect(await mock.lastCall() == "authDelete")
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
        #expect(result.stdout.contains("requested_version: 0.26.0"))
        #expect(await mock.lastCall() == "binaryInstall")
    }

    @Test("binary install rejects empty version")
    func binaryInstallRejectsEmptyVersion() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "install",
                "--version", "   ",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
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
        #expect(result.stdout.contains("current_version: -"))
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
        #expect(result.stdout.contains("selected_version_id: 0.26.0"))
        #expect(await mock.lastCall() == "binaryUse")
    }

    @Test("binary use rejects empty version")
    func binaryUseRejectsEmptyVersion() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "use",
                "--version", "\t",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
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
        #expect(result.stdout.contains("profile_path: ~/.zshrc"))
        #expect(await mock.lastCall() == "binaryDoctor")
    }

    @Test("binary list prints concise one-line items instead of json")
    func binaryListPrintsConciseOneLineItems() async {
        let service = BinaryListPlainTextCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "list"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        let lines = result.stdout.split(separator: "\n").map(String.init)
        #expect(lines.count == 2)
        #expect(lines[0].contains("* 0.26.0"))
        #expect(lines[1].contains("  0.9.0"))
        #expect(lines[0].contains("Codex 0.26.0"))
        #expect(lines[1].contains("X"))
        #expect(lines[0].contains("v0.26.0"))
        #expect(lines[1].contains("v0.9.0"))
        #expect(!result.stdout.contains("\"command\":\"codex.binary.list\""))
        #expect(!result.stdout.contains("\"ok\":true"))

        let firstPipeIndices = lines[0].indicesOfPipes()
        #expect(firstPipeIndices.count == 3)
        #expect(lines[1].indicesOfPipes() == firstPipeIndices)
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
        #expect(result.stdout.contains("resolved_executable"))
        #expect(result.stdout.contains("| /opt/homebrew/bin/codex"))
        #expect(await mock.lastCall() == "statusProbe")
    }

    @Test("routes runtime list")
    func routesRuntimeList() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "list"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("PID"))
        #expect(result.stdout.contains("运行时长"))
        #expect(await mock.lastCall() == "runtimeList")
    }

    @Test("routes runtime stop")
    func routesRuntimeStop() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "stop", "--pid", "12345"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("pid: 12345"))
        #expect(result.stdout.contains("signal: term"))
        #expect(await mock.lastCall() == "runtimeStop")
    }

    @Test("runtime stop rejects invalid pid")
    func runtimeStopRejectsInvalidPID() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "stop", "--pid", "0"],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
    }

    @Test("status probe prints aligned table rows")
    func statusProbePrintsAlignedTableRows() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "status", "probe",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        let rows = result.stdout.split(separator: "\n").map(String.init)
        #expect(rows.count >= 6)
        let firstPipeIndex = rows[0].firstIndex(of: "|")
        #expect(firstPipeIndex != nil)
        for row in rows {
            #expect(row.firstIndex(of: "|") == firstPipeIndex)
        }
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
        #expect(result.stdout.contains("| codex-xcode"))
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
        #expect(result.stderr.contains("\"code\":\"unsupported_command\""))
    }

    @Test("unsupported runtime command returns invalid arguments")
    func unsupportedRuntimeCommandError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "runtime", "unknown"],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"unsupported_command\""))
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

private extension String {
    func indicesOfPipes() -> [Int] {
        enumerated().compactMap { index, char in char == "|" ? index : nil }
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
            runtimeErrorDescription: nil,
            loginURL: "https://auth.example.com/device"
        )
    }

    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload {
        call = "authDelete"
        return NolonCodexAuthDeletePayload(
            providerID: providerID,
            accountID: accountID,
            wasActive: false
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

    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload {
        call = "runtimeList"
        return NolonCodexRuntimeListPayload(
            processes: [
                NolonCodexRuntimeProcessView(
                    pid: 12345,
                    ppid: 1,
                    elapsed: "00:01:02",
                    providerHint: "codex",
                    command: "/opt/homebrew/bin/codex"
                )
            ]
        )
    }

    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload {
        call = "runtimeStop"
        return NolonCodexRuntimeStopPayload(
            pid: pid,
            requestedSignal: force ? "kill" : "term",
            didEscalateToKill: false,
            exited: true
        )
    }
}

private actor DomainErrorCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw makeError() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw makeError() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw makeError() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw makeError() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw makeError() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw makeError() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw makeError() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw makeError() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw makeError() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw makeError() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw makeError() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw makeError() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw makeError() }

    private func makeError() -> NolonCoreCLIError {
        .domainFailed(code: "codex_binary_not_found", message: "missing")
    }
}

private actor BinaryListPlainTextCodexCLIService: NolonCodexCLIServing {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload { throw unsupported() }
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw unsupported() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }

    func binaryList() async throws -> NolonCodexBinaryListPayload {
        NolonCodexBinaryListPayload(
            selectedVersionID: "v0.26.0",
            versions: [
                NolonCodexManagedVersionView(
                    id: "v0.26.0",
                    displayName: "Codex 0.26.0",
                    detectedVersion: "0.26.0",
                    source: "release",
                    importedAt: .distantPast,
                    isSelected: true
                ),
                NolonCodexManagedVersionView(
                    id: "v0.9.0",
                    displayName: "X",
                    detectedVersion: "0.9.0",
                    source: "release",
                    importedAt: .distantPast,
                    isSelected: false
                ),
            ]
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor AuthListTableCodexCLIService: NolonCodexCLIServing {
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw unsupported() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    name: "long-account-name",
                    createdAt: .distantPast,
                    relativeAuthPath: "accounts/long-name/auth.json",
                    isActive: true,
                    email: "long-account@example.com",
                    usageDisplay: "5h 81% / 7d 55%",
                    refreshedAt: Date(timeIntervalSince1970: 1_734_000_000)
                ),
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    name: "x",
                    createdAt: .distantPast,
                    relativeAuthPath: "a.json",
                    isActive: false,
                    email: "x@example.com",
                    usageDisplay: "5h 40%",
                    refreshedAt: Date(timeIntervalSince1970: 1_733_900_000)
                ),
            ]
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}

private actor AuthListMissingFieldsCodexCLIService: NolonCodexCLIServing {
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload { throw unsupported() }
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload { throw unsupported() }
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload { throw unsupported() }
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload { throw unsupported() }
    func binaryList() async throws -> NolonCodexBinaryListPayload { throw unsupported() }
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload { throw unsupported() }
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload { throw unsupported() }
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload { throw unsupported() }
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload { throw unsupported() }
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload { throw unsupported() }
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload { throw unsupported() }
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload { throw unsupported() }

    func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: nil,
            accounts: [
                NolonCodexAuthAccountView(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    name: "unknown",
                    createdAt: .distantPast,
                    relativeAuthPath: "auth/missing.json",
                    isActive: false,
                    email: nil,
                    usageDisplay: nil,
                    refreshedAt: nil
                ),
            ]
        )
    }

    private func unsupported() -> NolonCoreCLIError {
        .invalidArguments("unsupported")
    }
}
