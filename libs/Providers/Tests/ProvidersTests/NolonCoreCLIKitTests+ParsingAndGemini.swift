import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

extension NolonCoreCLIKitTests {
    @Test("parse skills list command without options")
    func parseSkillsListWithoutOptions() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == nil)
        #expect(includeEmpty == false)
        #expect(state == nil)
        #expect(verbose == false)
        #expect(showFixes == false)
    }
    @Test("parse skills list command with state filter")
    func parseSkillsListWithStateFilter() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
                "--provider", "codex",
                "--state", "broken",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == "codex")
        #expect(includeEmpty == false)
        #expect(state == .broken)
        #expect(verbose == false)
        #expect(showFixes == false)
    }
    @Test("parse skills list command with verbose")
    func parseSkillsListWithVerbose() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
                "--provider", "codex",
                "--verbose",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == "codex")
        #expect(includeEmpty == false)
        #expect(state == nil)
        #expect(verbose == true)
        #expect(showFixes == false)
    }
    @Test("parse skills list command with show fixes")
    func parseSkillsListWithShowFixes() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
                "--provider", "codex",
                "--show-fixes",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == "codex")
        #expect(includeEmpty == false)
        #expect(state == nil)
        #expect(verbose == false)
        #expect(showFixes == true)
    }
    @Test("parse gemini auth usage command")
    func parseGeminiAuthUsage() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "gemini", "auth", "usage",
                "--provider", "gemini",
            ]
        )

        guard case let .geminiAuthUsage(provider) = command else {
            Issue.record("Expected .geminiAuthUsage")
            return
        }
        #expect(provider == "gemini")
    }
    @Test("parse gemini auth refresh command")
    func parseGeminiAuthRefresh() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "gemini", "auth", "refresh",
                "--provider", "antigravity",
            ]
        )

        guard case let .geminiAuthRefresh(provider) = command else {
            Issue.record("Expected .geminiAuthRefresh")
            return
        }
        #expect(provider == "antigravity")
    }
    @Test("parse gemini auth doctor command")
    func parseGeminiAuthDoctor() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "gemini", "auth", "doctor",
                "--provider", "gemini",
            ]
        )

        guard case let .geminiAuthDoctor(provider) = command else {
            Issue.record("Expected .geminiAuthDoctor")
            return
        }
        #expect(provider == "gemini")
    }
    @Test("legacy gemini usage command is rejected")
    func parseLegacyGeminiUsageCommandRejected() throws {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "gemini", "usage", "overview",
                    "--provider", "gemini",
                ]
            )
            Issue.record("Expected legacy command to be rejected")
        } catch {
            let message = (error as? NolonCoreCLIError)?.errorDescription ?? error.localizedDescription
            #expect(message.contains("Unknown option") || message.contains("gemini auth"))
        }
    }
    @Test("parse gemini auth usage requires provider")
    func parseGeminiAuthUsageRequiresProvider() throws {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                [
                    "gemini", "auth", "usage",
                ]
            )
            Issue.record("Expected parse failure for missing --provider")
        } catch {
            let message = (error as? NolonCoreCLIError)?.errorDescription ?? error.localizedDescription
            #expect(message.contains("--provider"))
        }
    }
    @Test("runner renders gemini auth usage json")
    func runnerRendersGeminiAuthUsageJSON() async throws {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" },
            geminiUsageFetchAction: { _ in [] },
            geminiTokenTrendFetchAction: { _ in
                ProviderTokenTrendSnapshot(
                    points: [
                        ProviderTokenTrendPoint(
                            date: "2026-03-08",
                            totalTokens: 320,
                            inputTokens: 200,
                            outputTokens: 100,
                            cacheReadTokens: 20
                        ),
                    ],
                    todayTokens: 320,
                    last7DaysTokens: 320,
                    last30DaysTokens: 320,
                    allDaysTokens: 320,
                    updatedAt: Date(timeIntervalSince1970: 1_709_900_000),
                    sourceLabel: "session"
                )
            }
        )

        let result = await runner.execute(
            arguments: [
                "gemini", "auth", "usage",
                "--provider", "gemini",
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"command\":\"gemini.auth.usage\""))
        #expect(result.stdout.contains("\"provider\":\"gemini\""))
        #expect(result.stdout.contains("\"entries\""))
        #expect(result.stdout.contains("\"token_trend\""))
        #expect(result.stdout.contains("\"today_tokens\":320"))
        #expect(result.stdout.contains("\"source\":\"session\""))
    }
    @Test("runner renders gemini auth usage text with token trend summary")
    func runnerRendersGeminiAuthUsageTextWithTokenTrend() async throws {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" },
            geminiUsageFetchAction: { _ in [] },
            geminiTokenTrendFetchAction: { _ in
                ProviderTokenTrendSnapshot(
                    points: [],
                    todayTokens: 320,
                    last7DaysTokens: 1280,
                    last30DaysTokens: 4096,
                    allDaysTokens: 4096,
                    updatedAt: Date(timeIntervalSince1970: 1_709_900_000),
                    sourceLabel: "session"
                )
            }
        )

        let result = await runner.execute(
            arguments: [
                "gemini", "auth", "usage",
                "--provider", "gemini",
            ],
            outputMode: .text
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("provider: gemini"))
        #expect(result.stdout.contains("token_trend: today=320 last7=1280 last30=4096"))
        #expect(result.stdout.contains("source=session"))
    }
    @Test("runner renders gemini auth doctor json with classified diagnostics")
    func runnerRendersGeminiAuthDoctorJSONWithDiagnostics() async throws {
        let keys = [
            "NOLON_GEMINI_USAGE_PRIMARY_USED_PERCENT",
            "NOLON_GEMINI_USAGE_SECONDARY_USED_PERCENT",
            "NOLON_GEMINI_USAGE_TERTIARY_USED_PERCENT",
            "NOLON_GEMINI_USAGE_EMAIL",
            "NOLON_GEMINI_USAGE_PLAN",
            "NOLON_GEMINI_USAGE_ORG",
            "NOLON_GEMINI_USAGE_LOGIN_METHOD",
            "NOLON_GEMINI_USAGE_UPDATED_AT",
        ]
        let backup = keys.map { ($0, getenv($0).map { String(cString: $0) }) }
        for key in keys {
            unsetenv(key)
        }
        defer {
            for (key, value) in backup {
                if let value {
                    setenv(key, value, 1)
                } else {
                    unsetenv(key)
                }
            }
        }

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "gemini", "auth", "doctor",
                "--provider", "gemini",
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        #expect(result.stdout.contains("\"command\":\"gemini.auth.doctor\""))
        #expect(result.stdout.contains("\"healthy\":false"))
        #expect(result.stdout.contains("\"diagnostics\""))
        #expect(
            result.stdout.contains("\"code\":\"auth\"")
                || result.stdout.contains("\"code\":\"parse\"")
                || result.stdout.contains("\"code\":\"binary\"")
                || result.stdout.contains("\"code\":\"timeout\"")
                || result.stdout.contains("\"code\":\"unsupported\"")
                || result.stdout.contains("\"code\":\"unknown\"")
        )
    }
    @Test("parse skills search command")
    func parseSkillsSearch() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "search",
                "--query", "agent",
                "--limit", "9",
                "--base-url", "https://clawhub.ai",
            ]
        )

        guard case let .skillsSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "agent")
        #expect(limit == 9)
        #expect(baseURL == "https://clawhub.ai")
        #expect(install == false)
        #expect(provider == nil)
        #expect(installMethod == .symlink)
        #expect(pick == nil)
        #expect(dryRun == false)
        #expect(assumeYes == false)
    }
    @Test("parse skills search positional query command")
    func parseSkillsSearchPositionalQuery() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "search", "xcode",
                "--limit", "9",
            ]
        )

        guard case let .skillsSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "xcode")
        #expect(limit == 9)
        #expect(baseURL == "https://clawhub.ai")
        #expect(install == false)
        #expect(provider == nil)
        #expect(installMethod == .symlink)
        #expect(pick == nil)
        #expect(dryRun == false)
        #expect(assumeYes == false)
    }
    @Test("parse skills search install command")
    func parseSkillsSearchInstall() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "search", "xcode",
                "--install",
                "--provider", "codex",
                "--install-method", "copy",
                "--dry-run",
            ]
        )

        guard case let .skillsSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "xcode")
        #expect(limit == 20)
        #expect(baseURL == "https://clawhub.ai")
        #expect(install == true)
        #expect(provider == "codex")
        #expect(installMethod == .copy)
        #expect(pick == nil)
        #expect(dryRun == true)
        #expect(assumeYes == false)
    }
    @Test("parse skills search install command with yes")
    func parseSkillsSearchInstallWithYes() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["skills", "search", "xcodebuildmcp", "--install", "--yes", "--provider", "codex"]
        )

        guard case let .skillsSearch(query, _, _, install, _, _, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "xcodebuildmcp")
        #expect(install == true)
        #expect(pick == nil)
        #expect(dryRun == false)
        #expect(assumeYes == true)
    }
    @Test("parse skills search install command with pick")
    func parseSkillsSearchInstallWithPick() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["skills", "search", "xco", "--install", "--pick", "2", "--dry-run"]
        )

        guard case let .skillsSearch(query, _, _, install, _, _, pick, dryRun, assumeYes) = command else {
            Issue.record("Expected .skillsSearch")
            return
        }
        #expect(query == "xco")
        #expect(install == true)
        #expect(pick == 2)
        #expect(dryRun == true)
        #expect(assumeYes == false)
    }
    @Test("parse skills search rejects install options without install")
    func parseSkillsSearchRejectsInstallOptionsWithoutInstall() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "search", "xcode", "--provider", "codex"]
            )
            Issue.record("Expected invalid install options error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("--provider requires --install"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse skills search install requires yes or dry-run")
    func parseSkillsSearchInstallRequiresYesOrDryRun() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "search", "xcodebuildmcp", "--install", "--provider", "codex"]
            )
            Issue.record("Expected missing confirmation error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("--yes"))
            #expect((error.errorDescription ?? "").contains("--dry-run"))
            #expect((error.errorDescription ?? "").contains("nolon skills search <keyword> --install --dry-run"))
            #expect((error.errorDescription ?? "").contains("nolon skills search <keyword> --install --yes --provider codex"))
            #expect((error.errorDescription ?? "").contains("nolon skills search --query <text> --install --dry-run"))
            #expect((error.errorDescription ?? "").contains("nolon skills search --query <text> --install --yes --provider codex"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse skills search rejects duplicate positional and option query")
    func parseSkillsSearchRejectsDuplicateQueryInputs() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "search", "xcode", "--query", "swift"]
            )
            Issue.record("Expected invalid query input error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("xcode"))
            #expect(message.contains("swift"))
            #expect(message.contains("nolon skills search xcode"))
            #expect(message.contains("nolon skills search --query swift"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse workflow search install requires yes or dry-run")
    func parseWorkflowSearchInstallRequiresYesOrDryRun() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["workflow", "search", "xcode", "--install", "--provider", "codex"]
            )
            Issue.record("Expected missing confirmation error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("--yes"))
            #expect(message.contains("--dry-run"))
            #expect(message.contains("nolon workflow search <keyword> --install --dry-run"))
            #expect(message.contains("nolon workflow search <keyword> --install --yes --provider codex"))
            #expect(message.contains("nolon workflow search --query <text> --install --dry-run"))
            #expect(message.contains("nolon workflow search --query <text> --install --yes --provider codex"))
            #expect(message.contains("nolon skills search") == false)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse mcp search install requires yes or dry-run")
    func parseMcpSearchInstallRequiresYesOrDryRun() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["mcp", "search", "xcode", "--install", "--provider", "codex"]
            )
            Issue.record("Expected missing confirmation error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("--yes"))
            #expect(message.contains("--dry-run"))
            #expect(message.contains("nolon mcp search <keyword> --install --dry-run"))
            #expect(message.contains("nolon mcp search <keyword> --install --yes --provider codex"))
            #expect(message.contains("nolon mcp search --query <text> --install --dry-run"))
            #expect(message.contains("nolon mcp search --query <text> --install --yes --provider codex"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse workflow search rejects duplicate positional and option query")
    func parseWorkflowSearchRejectsDuplicateQueryInputs() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["workflow", "search", "xcode", "--query", "swift"]
            )
            Issue.record("Expected invalid query input error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("xcode"))
            #expect(message.contains("swift"))
            #expect(message.contains("nolon workflow search xcode"))
            #expect(message.contains("nolon workflow search --query swift"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse mcp search rejects duplicate positional and option query")
    func parseMcpSearchRejectsDuplicateQueryInputs() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["mcp", "search", "xcode", "--query", "swift"]
            )
            Issue.record("Expected invalid query input error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            let message = error.errorDescription ?? ""
            #expect(message.contains("xcode"))
            #expect(message.contains("swift"))
            #expect(message.contains("nolon mcp search xcode"))
            #expect(message.contains("nolon mcp search --query swift"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse mcp server list command")
    func parseMcpServerList() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["mcp", "server", "list", "--provider", "codex"]
        )
        guard case let .mcpServerList(provider) = command else {
            Issue.record("Expected .mcpServerList")
            return
        }
        #expect(provider == "codex")
    }
    @Test("parse mcp server set-enabled command")
    func parseMcpServerSetEnabled() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["mcp", "server", "set-enabled", "--provider", "codex", "--name", "playwright", "--disabled"]
        )
        guard case let .mcpServerSetEnabled(provider, name, enabled) = command else {
            Issue.record("Expected .mcpServerSetEnabled")
            return
        }
        #expect(provider == "codex")
        #expect(name == "playwright")
        #expect(enabled == false)
    }
    @Test("parse mcp cache status command")
    func parseMcpCacheStatus() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["mcp", "cache", "status", "--provider", "codex", "--name", "playwright"]
        )
        guard case let .mcpCacheStatus(provider, name) = command else {
            Issue.record("Expected .mcpCacheStatus")
            return
        }
        #expect(provider == "codex")
        #expect(name == "playwright")
    }
    @Test("parse plugin install command")
    func parsePluginInstall() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["plugin", "install", "--name", "xcodemcpkit", "--provider", "codex", "--version", "v0.3.6", "--force"]
        )
        guard case let .pluginInstall(name, provider, version, force) = command else {
            Issue.record("Expected .pluginInstall")
            return
        }
        #expect(name == "xcodemcpkit")
        #expect(provider == "codex")
        #expect(version == "v0.3.6")
        #expect(force == true)
    }
    @Test("parse plugin stop command")
    func parsePluginStop() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            ["plugin", "stop", "--name", "xcodemcpkit", "--force"]
        )
        guard case let .pluginStop(name, force) = command else {
            Issue.record("Expected .pluginStop")
            return
        }
        #expect(name == "xcodemcpkit")
        #expect(force == true)
    }
    @Test("runner plugin install writes global mcp file with plugin marker")
    func runnerPluginInstallWritesGlobalMcpFileWithPluginMarker() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-plugin-install-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let nolonHome = tempRoot.folder("nolon-home")
        _ = nolonHome.createIfNotExists()
        let binDir = tempRoot.folder("bin")
        _ = binDir.createIfNotExists()
        try makeExecutableScript(at: binDir.file("xcodemcpkit").url.path)
        try makeExecutableScript(at: binDir.file("xcode-mcp-server").url.path)

        let backupHome = getenv("NOLON_HOME").map { String(cString: $0) }
        let backupPath = getenv("PATH").map { String(cString: $0) } ?? ""
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        setenv("PATH", "\(binDir.url.path):\(backupPath)", 1)
        defer {
            if let backupHome {
                setenv("NOLON_HOME", backupHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
            setenv("PATH", backupPath, 1)
        }

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: ["plugin", "install", "--name", "xcodemcpkit"],
            outputMode: .json
        )

        #expect(result.exitCode == 0)
        let globalMcpPath = nolonHome.folder("mcps").file("xcodemcpkit.json")
        #expect(globalMcpPath.isExists)
        let content = try globalMcpPath.read()
        #expect(content.contains("\"nolon_plugin\""))
        #expect(content.contains("\"plugin_id\" : \"xcodemcpkit\""))
        #expect(content.contains("\"managed\" : true"))
        #expect(content.contains("\"mcpServers\""))
        #expect(content.contains("\"command\" : \"xcode-mcp-server\""))
    }
    @Test("runner plugin uninstall rejects non-plugin-managed global mcp entry")
    func runnerPluginUninstallRejectsNonPluginManagedGlobalMcpEntry() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-plugin-uninstall-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let nolonHome = tempRoot.folder("nolon-home")
        let mcpsDir = nolonHome.folder("mcps")
        _ = mcpsDir.createIfNotExists()
        let binDir = tempRoot.folder("bin")
        _ = binDir.createIfNotExists()
        try makeExecutableScript(at: binDir.file("xcodemcpkit").url.path)
        try makeExecutableScript(at: binDir.file("xcodemcpkit").url.path)
        let globalMcpPath = mcpsDir.file("xcodemcpkit.json")
        try """
        {
          "name": "XcodeMCPKit",
          "mcpServers": {
            "xcodemcpkit": {
              "command": "xcode-mcp-server",
              "enabled": true
            }
          }
        }
        """.write(to: globalMcpPath.url, atomically: true, encoding: .utf8)

        let backupHome = getenv("NOLON_HOME").map { String(cString: $0) }
        let backupPath = getenv("PATH").map { String(cString: $0) } ?? ""
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        setenv("PATH", "\(binDir.url.path):\(backupPath)", 1)
        defer {
            if let backupHome {
                setenv("NOLON_HOME", backupHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
            setenv("PATH", backupPath, 1)
        }

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: ["plugin", "uninstall", "--name", "xcodemcpkit"],
            outputMode: .json
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"plugin_not_managed_by_nolon\""))
        #expect(globalMcpPath.isExists)
    }
    @Test("runner plugin uninstall treats invalid global json as unmanaged and blocks deletion")
    func runnerPluginUninstallTreatsInvalidGlobalJSONAsUnmanaged() async throws {
        let tempRoot = try STFolder(sanbox: .temporary).folder("nolon-cli-plugin-invalid-json-\(UUID().uuidString)").create()
        defer { try? tempRoot.delete() }

        let nolonHome = tempRoot.folder("nolon-home")
        let mcpsDir = nolonHome.folder("mcps")
        _ = mcpsDir.createIfNotExists()
        let binDir = tempRoot.folder("bin")
        _ = binDir.createIfNotExists()
        try makeExecutableScript(at: binDir.file("xcodemcpkit").url.path)
        try makeExecutableScript(at: binDir.file("xcode-mcp-server").url.path)
        let globalMcpPath = mcpsDir.file("xcodemcpkit.json")
        try "{ invalid-json".write(to: globalMcpPath.url, atomically: true, encoding: .utf8)

        let backupHome = getenv("NOLON_HOME").map { String(cString: $0) }
        let backupPath = getenv("PATH").map { String(cString: $0) } ?? ""
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        setenv("PATH", "\(binDir.url.path):\(backupPath)", 1)
        defer {
            if let backupHome {
                setenv("NOLON_HOME", backupHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
            setenv("PATH", backupPath, 1)
        }

        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )
        let result = await runner.execute(
            arguments: ["plugin", "uninstall", "--name", "xcodemcpkit"],
            outputMode: .json
        )

        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("\"code\":\"plugin_not_managed_by_nolon\""))
        #expect(globalMcpPath.isExists)
    }
}
