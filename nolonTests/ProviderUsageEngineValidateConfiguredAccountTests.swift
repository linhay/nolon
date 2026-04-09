import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class ProviderUsageEngineValidateConfiguredAccountTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDownWithError() throws {
        let fileManager = FileManager.default
        for directory in tempDirectories {
            try? fileManager.removeItem(at: directory)
        }
        tempDirectories.removeAll()
    }

    func testBDD_GivenRandomInputFactory_WhenCalledTwice_ThenEachInputIsUnique() {
        let first = ProviderUsageEngine.makeRandomCodexValidationInput()
        let second = ProviderUsageEngine.makeRandomCodexValidationInput()

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.hasPrefix("nolon-connectivity-"))
        XCTAssertTrue(second.hasPrefix("nolon-connectivity-"))
    }

    func testBDD_GivenActiveConfiguredAccount_WhenValidating_ThenUsesValidationActionAndShowsAlert() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "relay", relativeAuthPath: "auth/relay.json")
        let validateCallCount = AsyncIntBox(0)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexConfiguredAccountValidateAction: { _ in
                await validateCallCount.increment()
                return "validation-ok"
            }
        )
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(cardKind: .officialAPIKey)

        viewModel.validateActiveCodexConfiguredAccount()

        try await waitUntil {
            viewModel.alertMessage == "validation-ok"
        }
        let calls = await validateCallCount.value()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(
            viewModel.alertTitle,
            NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")
        )
    }

    func testBDD_GivenNewConfigEditor_WhenOpening_ThenLoadsModelProviderOptionsFromModelsCache() throws {
        let root = try makeTempDirectory()
        let providerHome = root.appendingPathComponent("provider-home", isDirectory: true)
        let skillsPath = providerHome.appendingPathComponent("skills", isDirectory: true).path
        let homePath = root.appendingPathComponent("home", isDirectory: true).path
        try FileManager.default.createDirectory(at: providerHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: homePath).appendingPathComponent(".codex", isDirectory: true),
            withIntermediateDirectories: true
        )

        try writeModelsCache(
            to: providerHome.appendingPathComponent("models_cache.json"),
            models: [
                #"{"slug":"gpt-5.4","display_name":"gpt-5.4","visibility":"list"}"#,
                #"{"slug":"gpt-5.4-mini","display_name":"gpt-5.4-mini","visibility":"hide"}"#
            ]
        )
        try writeModelsCache(
            to: URL(fileURLWithPath: homePath).appendingPathComponent(".codex/models_cache.json"),
            models: [
                #"{"slug":"gpt-5.2-codex","display_name":"gpt-5.2-codex","visibility":"list"}"#
            ]
        )

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skillsPath,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let service = CodexModelPreferenceService(homeDirectoryPath: { homePath })
        let viewModel = ProviderUsageEngine(provider: provider, codexModelPreferenceService: service)

        viewModel.beginNewCodexAPIKeyAccount()

        XCTAssertEqual(viewModel.codexConfigEditorModelProviderOptions, ["gpt-5.4", "gpt-5.2-codex"])
    }

    func testBDD_GivenEditConfigEditor_WhenCurrentProviderNotInCache_ThenCurrentProviderIsKeptInOptions() throws {
        let root = try makeTempDirectory()
        let providerHome = root.appendingPathComponent("provider-home", isDirectory: true)
        let skillsPath = providerHome.appendingPathComponent("skills", isDirectory: true).path
        let homePath = root.appendingPathComponent("home", isDirectory: true).path
        try FileManager.default.createDirectory(at: providerHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: homePath).appendingPathComponent(".codex", isDirectory: true),
            withIntermediateDirectories: true
        )

        try writeModelsCache(
            to: providerHome.appendingPathComponent("models_cache.json"),
            models: [
                #"{"slug":"gpt-5.4","display_name":"gpt-5.4","visibility":"list"}"#
            ]
        )

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skillsPath,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let service = CodexModelPreferenceService(homeDirectoryPath: { homePath })
        let account = CodexAuthAccount(name: "relay", relativeAuthPath: "auth/relay.json")
        let viewModel = ProviderUsageEngine(provider: provider, codexModelPreferenceService: service)
        viewModel.codexAccounts = [account]
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(
            cardKind: .relayProfile,
            relayModelProvider: "custom-provider"
        )

        viewModel.beginEditCodexConfiguredAccount(id: account.id)

        XCTAssertEqual(
            viewModel.codexConfigEditorModelProviderOptions,
            ["custom-provider", "gpt-5.4"]
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        pollIntervalNanoseconds: UInt64 = 20_000_000,
        condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        XCTFail("Condition was not met before timeout")
    }

    private func makeTempDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempDirectories.append(directory)
        return directory
    }

    private func writeModelsCache(to fileURL: URL, models: [String]) throws {
        let payload = """
        {
          "fetched_at": "2026-04-01T00:00:00Z",
          "models":[\(models.joined(separator: ","))]
        }
        """
        try Data(payload.utf8).write(to: fileURL, options: .atomic)
    }
}
