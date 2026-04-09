import Foundation
import Testing
import CodexGatewayKit
@testable import NolonCoreCLIKit

extension NolonCodexCLIEntrypointTests {
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
    @Test("codex status doctor --help prints action help")
    func codexStatusDoctorHelpPrintsHelp() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "doctor", "--help"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Usage: nolon codex status doctor"))
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
        #expect(result.stdout.contains("[账号]"))
        #expect(result.stdout.contains("[用量]"))
        #expect(result.stdout.contains("[状态]"))
        #expect(result.stdout.contains("邮箱"))
        #expect(result.stdout.contains("状态"))
        #expect(result.stdout.contains("令牌健康"))
        #expect(result.stdout.contains("5h剩余"))
    }
    @Test("routes auth usage per-account table")
    func routesAuthUsage() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("[账号]"))
        #expect(result.stdout.contains("[用量]"))
        #expect(result.stdout.contains("[状态]"))
        #expect(result.stdout.contains("5h剩余"))
        #expect(result.stdout.contains("7d剩余"))
        #expect(result.stdout.contains("Tokens汇总 | 1d"))
        #expect(result.stdout.contains("| all"))
        #expect(result.stdout.contains("Access:"))
        #expect(result.stdout.contains("Refresh:"))
    }
    @Test("routes auth usage refresh with summary")
    func routesAuthUsageRefreshSummary() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage",
                "--provider", "codex",
                "--summary",
                "--refresh",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("账号总数"))
        #expect(await mock.lastCall() == "authUsageRefresh")
    }
    @Test("routes auth usage-trend table")
    func routesAuthUsageTrendTable() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage-trend",
                "--provider", "codex",
                "--range", "7d",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("provider | codex"))
        #expect(result.stdout.contains("range | 7d"))
        #expect(result.stdout.contains("summary.today | 1.2亿"))
        #expect(result.stdout.contains("date | total | input | output | cache"))
        #expect(result.stdout.contains("2026-02-26 |"))
        #expect(await mock.lastCall() == "authUsageTrend")
    }
    @Test("auth usage-trend rejects invalid range")
    func authUsageTrendRejectsInvalidRange() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage-trend",
                "--provider", "codex",
                "--range", "2d",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Supported values: 7d, 30d, all"))
    }
    @Test("auth usage target requires refresh flag")
    func authUsageTargetRequiresRefreshFlag() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage",
                "--provider", "codex",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("requires --refresh"))
    }
    @Test("auth usage summary renders aggregated rows")
    func authUsageSummaryRenders() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "usage",
                "--provider", "codex",
                "--summary",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("账号总数"))
        #expect(result.stdout.contains("已缓存用量"))
        #expect(result.stdout.contains("5h平均剩余"))
        #expect(result.stdout.contains("Tokens | 1d"))
        #expect(result.stdout.contains("| all"))
    }
    @Test("auth usage expiry shows relative remaining and expired labels")
    func authUsageExpiryShowsRelativeLabels() async {
        let service = AuthUsageExpiryLabelCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("剩余"))
        #expect(result.stdout.contains("已过期"))
        #expect(result.stdout.contains("Refresh:可用"))
    }
    @Test("auth usage shows fallback hint when all token sources are global")
    func authUsageShowsGlobalFallbackHint() async {
        let service = AuthUsageGlobalFallbackCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("提示: 当前 Tokens 来自全局回退"))
    }
    @Test("auth usage hides per-account tokens when source is not distinguishable")
    func authUsageHidesPerAccountTokensWhenNotDistinguishable() async {
        let service = AuthUsageUndistinguishableTokensCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("Tokens汇总 | 1d"))
        #expect(!result.stdout.contains("Tokens 当前无法按账号区分"))
    }
    @Test("auth usage renders per-account refresh failure section")
    func authUsageRendersRefreshFailureSection() async {
        let service = AuthUsageRefreshFailureCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("broken@example.com"))
        #expect(result.stdout.contains("failed"))
        #expect(result.stdout.contains("other"))
    }
    @Test("auth usage overview resolves active account consistently by status")
    func authUsageOverviewResolvesActiveAccountByStatus() async {
        let service = AuthUsageActiveConsistencyCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("激活账号"))
        #expect(result.stdout.contains("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))
        #expect(result.stdout.contains("* second@example.com"))
        #expect(!result.stdout.contains("* first@example.com"))
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
        let headerIndex = lines.firstIndex { $0.contains("邮箱") && $0.contains("状态") && $0.contains("令牌健康") }
        #expect(headerIndex != nil)
        let rows = lines
            .dropFirst((headerIndex ?? 0) + 1)
            .prefix { !$0.hasPrefix("[用量]") && !$0.hasPrefix("[状态]") }
            .filter { $0.hasPrefix("* ") || ($0.hasPrefix("  ") && $0.contains(" | ")) }
        #expect(rows.count == 2)
        let firstPipeIndices = rows[0].indicesOfPipes()
        #expect(firstPipeIndices.count == 2)
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
        #expect(result.stdout.contains("[账号]"))
        #expect(result.stdout.contains("[用量]"))
        #expect(result.stdout.contains("[状态]"))
        #expect(result.stdout.contains("账号总数"))
        #expect(result.stdout.contains("已缓存用量"))
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
    @Test("routes auth refresh via account id")
    func routesAuthRefresh() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "refresh",
                "--provider", "codex",
                "--account-id", "11111111-1111-1111-1111-111111111111",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("* mock@example.com"))
        #expect(result.stdout.contains("| 已激活 | 成功"))
        #expect(result.stdout.contains("运行时切换"))
        #expect(result.stdout.contains("汇总-总数: 1"))
        #expect(await mock.lastCall() == "authRefresh")
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
    @Test("auth activate supports tui selection by email")
    func authActivateSupportsTUISelectionByEmail() throws {
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
            input: "B@Example.com",
            accounts: accounts
        )
        #expect(selected == UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!)
    }
    @Test("auth activate picker shows usage in table rows")
    func authActivatePickerShowsUsage() {
        let accounts: [NolonCodexAuthAccountView] = [
            NolonCodexAuthAccountView(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "A",
                createdAt: .distantPast,
                relativeAuthPath: "a/auth.json",
                isActive: true,
                email: "a@example.com",
                usageDisplay: "5h 80% / 7d 50%",
                refreshedAt: nil
            ),
        ]

        let text = NolonCodexCLIExecutor.renderActivatePicker(accounts: accounts)
        #expect(text.contains("编号 | 状态 | 邮箱"))
        #expect(text.contains("5h 80% / 7d 50%"))
        #expect(text.contains("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
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
    @Test("auth activate without account id defaults to interactive flow")
    func authActivateDefaultsToInteractiveFlow() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--provider", "codex",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Interactive selection requires a TTY terminal. Use --account-id <uuid> or --email <email>."))
    }
    @Test("auth activate supports email option for non-interactive usage")
    func authActivateSupportsEmailOption() async {
        let mock = EmailActivateCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--provider", "codex",
                "--email", "a@example.com",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("account_id: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
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
                "0.26.0",
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
                "   ",
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
    @Test("routes binary available")
    func routesBinaryAvailable() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "available",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(await mock.lastCall() == "binaryAvailable")
    }
}
