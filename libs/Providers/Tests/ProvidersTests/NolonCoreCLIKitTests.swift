import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

@Suite("NolonCoreCLIKit", .serialized)
struct NolonCoreCLIKitTests {
    @Test("parse skills repo plan command")
    func parseSkillsRepoPlan() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "repo", "plan",
                "--source", "vercel/agent-skills/skills/react-best-practices",
                "--repositories-root", "/tmp/repos"
            ]
        )

        guard case let .skillsRepoPlan(source, root, pull, credential, accessToken) = command else {
            Issue.record("Expected .skillsRepoPlan")
            return
        }

        #expect(source == "vercel/agent-skills/skills/react-best-practices")
        #expect(root == "/tmp/repos")
        #expect(pull == .ffOnly)
        #expect(credential == .automatic)
        #expect(accessToken == nil)
    }
    @Test("missing required option returns invalid arguments")
    func missingRequiredOption() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(
                ["skills", "repo", "plan", "--repositories-root", "/tmp/repos"]
            )
            Issue.record("Expected missing option error")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect(error.localizedDescription.contains("--source"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("runner renders success json for plan command")
    func runnerRendersSuccessJSON() async throws {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "repo", "plan",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos"
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"ok\":true"))
        #expect(result.stdout.contains("\"command\":\"skills.repo.plan\""))
        #expect(result.stdout.contains("\"preflight\""))
        #expect(result.stdout.contains("\"credentialMode\":\"https_anonymous\""))
        #expect(result.stdout.contains("\"issues\""))
        #expect(result.stderr.isEmpty)
    }
    @Test("json contract snapshot for remote list success")
    func jsonContractSnapshotRemoteListSuccess() async throws {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "remote", "list",
                "--kind", "skill",
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)

        let expected = #"{"command":"remote.list","data":{"result":{"base_url":"https:\/\/clawhub.ai","items":[],"kind":"skill","limit":20}},"ok":true}"#
        #expect(try canonicalJSON(result.stdout) == expected)
    }
    @Test("json contract snapshot for missing required option")
    func jsonContractSnapshotMissingRequiredOption() async throws {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "remote", "list",
            ]
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)

        #expect(result.stderr.contains("\"code\":\"invalid_arguments\""))
        #expect(result.stderr.contains("--kind"))
    }
    @Test("runner renders sync output with repository resources")
    func runnerRendersSyncWithResources() async {
        let runner = NolonCoreCLIRunner(
            service: MockSkillsRepositoryService(),
            fileReader: { _ in "" }
        )

        let result = await runner.execute(
            arguments: [
                "skills", "repo", "sync",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos"
            ]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"command\":\"skills.repo.sync\""))
        #expect(result.stdout.contains("\"resources\""))
        #expect(result.stdout.contains("\"workflows\""))
        #expect(result.stdout.contains("\"mcps\""))
        #expect(result.stdout.contains("\"defaultBranch\":\"main\""))
        #expect(result.stdout.contains("\"credentialMode\":\"https_token\""))
    }
    @Test("parse skills repo sync with lifecycle strategies")
    func parseSkillsRepoSyncWithStrategies() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "repo", "sync",
                "--source", "vercel/agent-skills",
                "--repositories-root", "/tmp/repos",
                "--pull-strategy", "rebase",
                "--credential-strategy", "token-only",
            ]
        )

        guard case let .skillsRepoSync(_, _, _, pullStrategy, credentialStrategy) = command else {
            Issue.record("Expected .skillsRepoSync with strategies")
            return
        }

        #expect(pullStrategy == .rebase)
        #expect(credentialStrategy == .tokenOnly)
    }
    @Test("parse skills sync command defaults repositories root")
    func parseSkillsSyncDefaultsRepositoriesRoot() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "sync",
                "--source", "vercel/agent-skills",
            ]
        )

        guard case let .skillsRepoSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy) = command else {
            Issue.record("Expected .skillsRepoSync")
            return
        }
        #expect(source == "vercel/agent-skills")
        #expect(repositoriesRoot.hasSuffix("/repositories"))
        #expect(accessToken == nil)
        #expect(pullStrategy == .ffOnly)
        #expect(credentialStrategy == .automatic)
    }
    @Test("parse skills repo without action returns missing subcommand error")
    func parseSkillsRepoWithoutActionReturnsMissingSubcommandError() {
        do {
            _ = try NolonCoreCLIArgumentParser.parse(["skills", "repo"])
            Issue.record("Expected invalid_arguments")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("Missing command. Expected: skills repo <action> ..."))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    @Test("parse skills repo preflight command")
    func parseSkillsRepoPreflight() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "repo", "preflight",
                "--source", "vercel/agent-skills",
                "--pull-strategy", "ff-only",
                "--credential-strategy", "token-only",
            ]
        )

        guard case let .skillsRepoPreflight(source, pull, credential, accessToken) = command else {
            Issue.record("Expected .skillsRepoPreflight")
            return
        }
        #expect(source == "vercel/agent-skills")
        #expect(pull == .ffOnly)
        #expect(credential == .tokenOnly)
        #expect(accessToken == nil)
    }
    @Test("parse skills repo list command")
    func parseSkillsRepoList() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "repo", "list",
                "--repositories-root", "/tmp/repos",
                "--max-depth", "7",
                "--verbose",
            ]
        )

        guard case let .skillsRepoList(repositoriesRoot, maxDepth, verbose) = command else {
            Issue.record("Expected .skillsRepoList")
            return
        }
        #expect(repositoriesRoot == "/tmp/repos")
        #expect(maxDepth == 7)
        #expect(verbose == true)
    }
    @Test("parse skills list command")
    func parseSkillsList() throws {
        let command = try NolonCoreCLIArgumentParser.parse(
            [
                "skills", "list",
                "--provider", "codex",
                "--include-empty",
            ]
        )

        guard case let .skillsList(provider, includeEmpty, state, verbose, showFixes) = command else {
            Issue.record("Expected .skillsList")
            return
        }
        #expect(provider == "codex")
        #expect(includeEmpty == true)
        #expect(state == nil)
        #expect(verbose == false)
        #expect(showFixes == false)
    }
}
