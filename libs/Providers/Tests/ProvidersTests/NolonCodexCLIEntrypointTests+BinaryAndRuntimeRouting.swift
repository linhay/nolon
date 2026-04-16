import Foundation
import Testing
@testable import NolonCoreCLIKit

extension NolonCodexCLIEntrypointTests {
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
    @Test("binary switch rejects non-tty")
    func binarySwitchRejectsNonTTY() async {
        let service = BinarySwitchCodexCLIService(
            installed: NolonCodexBinaryListPayload(selectedVersionID: nil, versions: []),
            available: NolonCodexBinaryAvailablePayload(versions: [])
        )
        let overrides = NolonCodexCLIExecutor.IOOverrides(
            isTTY: { false },
            readInputLine: { "1" },
            writePrompt: { _ in }
        )

        let result = await NolonCodexCLIExecutor.withIOOverrides(overrides) {
            await NolonCLIEntrypoint.execute(
                arguments: ["codex", "binary", "switch"],
                codexService: service
            )
        }

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Interactive selection requires a TTY"))
    }
    @Test("binary switch activates installed version")
    func binarySwitchActivatesInstalledVersion() async {
        let service = BinarySwitchCodexCLIService(
            installed: NolonCodexBinaryListPayload(
                selectedVersionID: "v0.26.0",
                versions: [
                    NolonCodexManagedVersionView(
                        id: "v0.26.0",
                        displayName: "Codex 0.26.0",
                        detectedVersion: "0.26.0",
                        source: "release",
                        importedAt: .distantPast,
                        isSelected: true
                    )
                ]
            ),
            available: NolonCodexBinaryAvailablePayload(versions: [])
        )
        let overrides = NolonCodexCLIExecutor.IOOverrides(
            isTTY: { true },
            readInputLine: { "1" },
            writePrompt: { _ in }
        )

        let result = await NolonCodexCLIExecutor.withIOOverrides(overrides) {
            await NolonCLIEntrypoint.execute(
                arguments: ["codex", "binary", "switch"],
                codexService: service
            )
        }

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("action: activate"))
        #expect(result.stdout.contains("selected_version_id: v0.26.0"))
        #expect(await service.lastCall() == "binaryUse")
    }
    @Test("binary switch installs available version")
    func binarySwitchInstallsAvailableVersion() async {
        let service = BinarySwitchCodexCLIService(
            installed: NolonCodexBinaryListPayload(selectedVersionID: nil, versions: []),
            available: NolonCodexBinaryAvailablePayload(
                versions: [
                    NolonCodexRemoteVersionView(
                        version: "0.100.0",
                        tag: "rust-v0.100.0",
                        downloadURL: "https://example.com/codex.tar.gz",
                        isPrerelease: false
                    )
                ]
            )
        )
        let overrides = NolonCodexCLIExecutor.IOOverrides(
            isTTY: { true },
            readInputLine: { "1" },
            writePrompt: { _ in }
        )

        let result = await NolonCodexCLIExecutor.withIOOverrides(overrides) {
            await NolonCLIEntrypoint.execute(
                arguments: ["codex", "binary", "switch"],
                codexService: service
            )
        }

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("action: install"))
        #expect(result.stdout.contains("requested_version: 0.100.0"))
        #expect(await service.lastCall() == "binaryInstall")
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
    @Test("status probe degrades parse errors to warning output")
    func statusProbeDegradesParseErrorsToWarning() async {
        let mock = StatusProbeParseErrorCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "probe", "--provider", "codex"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("probe_warning"))
        #expect(result.stdout.contains("Could not parse Codex status"))
        #expect(result.stdout.contains("probe_hint"))
        #expect(result.stdout.contains("nolon codex status doctor --json"))
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
    @Test("routes provider discover")
    func routesProviderDiscover() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "provider", "discover"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("provider"))
        #expect(result.stdout.contains("auth_state"))
        #expect(await mock.lastCall() == "providerDiscover")
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
    @Test("routes status doctor")
    func routesStatusDoctor() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "status", "doctor"],
            codexService: mock
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("检查项"))
        #expect(result.stdout.contains("status_probe"))
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
        #expect(result.stderr.contains("Available actions for status"))
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
        #expect(result.stderr.contains("Available actions for runtime"))
    }
    @Test("unknown codex group returns actionable error")
    func unknownCodexGroupReturnsActionableError() async {
        let mock = MockCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "unknown", "list"],
            codexService: mock
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("Unknown group 'unknown'"))
        #expect(result.stderr.contains("Available groups"))
    }
    @Test("json flag returns structured payload")
    func jsonFlagReturnsStructuredPayload() async {
        let service = BinaryListPlainTextCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "list", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"ok\":true"))
        #expect(result.stdout.contains("\"command\":\"codex.binary.list\""))
        #expect(result.stdout.contains("\"versions\""))
    }
    @Test("json flag before plugin command routes to core CLI")
    func jsonFlagBeforePluginCommandRoutesToCoreCLI() async {
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["--json", "plugin", "status", "--name", "xcodemcpkit"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"ok\":true"))
        #expect(result.stdout.contains("\"command\":\"plugin.status\""))
    }
    @Test("json flag after plugin command routes to core CLI")
    func jsonFlagAfterPluginCommandRoutesToCoreCLI() async {
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["plugin", "status", "--name", "xcodemcpkit", "--json"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"ok\":true"))
        #expect(result.stdout.contains("\"command\":\"plugin.status\""))
    }
    @Test("json contract snapshot for codex binary list success")
    func jsonContractSnapshotBinaryListSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "binary", "list", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.binary.list","data":{"selectedVersionID":"v1","versions":[{"detectedVersion":"1.0.0","displayName":"Codex 1.0.0","id":"v1","importedAt":"1970-01-01T00:00:00Z","isSelected":true,"source":"download"}]},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }
    @Test("json contract snapshot for codex auth list success")
    func jsonContractSnapshotAuthListSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "list", "--provider", "codex", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.list","data":{"accounts":[{"createdAt":"1970-01-01T00:00:00Z","email":"json@example.com","id":"11111111-1111-1111-1111-111111111111","isActive":true,"name":"json-account","refreshedAt":"1970-01-01T00:01:00Z","relativeAuthPath":"accounts\/json\/auth.json","usageDisplay":"5h 80% \/ 7d 60%"}],"activeAccountID":"11111111-1111-1111-1111-111111111111","providerID":"codex"},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }
    @Test("json contract snapshot for codex auth usage success")
    func jsonContractSnapshotAuthUsageSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage", "--provider", "codex", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.usage","data":{"accounts":[{"email":"json@example.com","expiresAt":"2026-12-31T08:00:00Z","fiveHourRemainingPercent":80,"id":"11111111-1111-1111-1111-111111111111","isActive":true,"isSkipped":false,"refreshedAt":"1970-01-01T00:00:00Z","status":"healthy","token1dCount":1200000,"token30dCount":24000000,"tokenAllCount":50000000,"weeklyRemainingPercent":60}],"providerID":"codex","refreshOrder":[],"skippedAccounts":[],"summary":{"accountCount":1,"avgFiveHourRemainingPercent":80,"avgWeeklyRemainingPercent":60,"cachedCount":1,"earliestExpiresAt":"2026-12-31T08:00:00Z","latestRefreshedAt":"1970-01-01T00:00:00Z","totalToken1dCount":1200000,"totalToken30dCount":24000000,"totalTokenAllCount":50000000}},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }
    @Test("json contract snapshot for codex auth usage-trend success")
    func jsonContractSnapshotAuthUsageTrendSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "usage-trend", "--provider", "codex", "--range", "7d", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        let data = try #require(result.stdout.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        let root = try #require(object as? [String: Any])
        #expect((root["ok"] as? Bool) == true)
        #expect((root["command"] as? String) == "codex.auth.usage-trend")
        let payload = try #require(root["data"] as? [String: Any])
        #expect((payload["providerID"] as? String) == "codex")
        #expect((payload["range"] as? String) == "7d")
        #expect((payload["sourceLabel"] as? String) == "global local usage")
        let points = try #require(payload["points"] as? [[String: Any]])
        #expect(points.count == 2)
        #expect((points.first?["date"] as? String) == "2026-02-26")
        let summary = try #require(payload["summary"] as? [String: Any])
        #expect((summary["todayTokens"] as? Int) == 2_500_000)
        #expect((summary["last7DaysTokens"] as? Int) == 4_450_000)
        #expect((summary["last30DaysTokens"] as? Int) == 4_450_000)
    }
    @Test("json contract snapshot for codex auth status success")
    func jsonContractSnapshotAuthStatusSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "auth", "status", "--provider", "codex", "--json"],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.status","data":{"accountCount":2,"activeAccountID":"22222222-2222-2222-2222-222222222222","authHashHex":"abc123","providerID":"codex","usageAvgFiveHourRemainingPercent":70,"usageAvgWeeklyRemainingPercent":55,"usageCachedAccountCount":2,"usageLatestRefreshedAt":"1970-01-01T00:01:00Z"},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }
    @Test("json contract snapshot for codex auth activate success")
    func jsonContractSnapshotAuthActivateSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "activate",
                "--provider", "codex",
                "--account-id", "33333333-3333-3333-3333-333333333333",
                "--json",
            ],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.activate","data":{"accountID":"33333333-3333-3333-3333-333333333333","providerID":"codex"},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }
    @Test("json contract snapshot for codex auth login success")
    func jsonContractSnapshotAuthLoginSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "login",
                "--provider", "codex",
                "--preferred-account-id", "44444444-4444-4444-4444-444444444444",
                "--json",
            ],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.login","data":{"accountID":"44444444-4444-4444-4444-444444444444","accountName":"json-login","loginURL":"https:\/\/auth.example.com\/device","providerID":"codex"},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }
    @Test("json contract snapshot for codex auth refresh success")
    func jsonContractSnapshotAuthRefreshSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "refresh",
                "--provider", "codex",
                "--account-id", "44444444-4444-4444-4444-444444444444",
                "--json",
            ],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.refresh","data":{"items":[{"accountID":"44444444-4444-4444-4444-444444444444","accountName":"json-refresh","email":"json@example.com","isActive":true,"success":true}],"providerID":"codex","summary":{"failureCount":0,"successCount":1,"totalCount":1}},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }
    @Test("json contract snapshot for codex auth delete success")
    func jsonContractSnapshotAuthDeleteSuccess() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "auth", "delete",
                "--provider", "codex",
                "--account-id", "55555555-5555-5555-5555-555555555555",
                "--json",
            ],
            codexService: service
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"codex.auth.delete","data":{"accountID":"55555555-5555-5555-5555-555555555555","providerID":"codex","wasActive":true},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }
    @Test("json contract snapshot for unknown codex group error")
    func jsonContractSnapshotUnknownGroupError() async throws {
        let service = JSONContractCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: ["codex", "oops", "list"],
            codexService: service
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)

        let expected = #"{"error":{"code":"invalid_arguments","message":"Unknown group 'oops'. Available groups: auth, binary, provider, runtime, session, status."},"ok":false}"#
        #expect(try canonicalJSON(result.stderr) == expected)
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
    @Test("cancellation maps to interrupted structured error")
    func cancellationMapsToInterruptedError() async {
        let mock = CancellationErrorCodexCLIService()
        let result = await NolonCLIEntrypoint.execute(
            arguments: [
                "codex", "binary", "use",
                "--version", "v0.1.0",
            ],
            codexService: mock
        )

        #expect(result.exitCode == 130)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("\"code\":\"interrupted\""))
        #expect(result.stderr.contains("Operation cancelled"))
    }
}
