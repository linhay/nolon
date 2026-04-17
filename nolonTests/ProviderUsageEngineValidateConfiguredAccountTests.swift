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

    func testBDD_GivenOfficialAPIKeyAccount_WhenEditingFromCardMenu_ThenOpensConfigEditorSheet() async throws {
        let root = try makeTempDirectory()
        let manager = CodexAuthManager(rootURL: root)
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("skills", isDirectory: true).path,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-live-12345678",
            relay: nil
        )
        let viewModel = ProviderUsageEngine(provider: provider, codexAuthManager: manager)
        viewModel.codexAccounts = [account]
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(cardKind: .officialAPIKey)

        viewModel.editCodexAccountAuthJSON(id: account.id)

        XCTAssertTrue(viewModel.isShowingCodexConfigEditor)
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.mode, .edit(accountID: account.id))
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.apiKey, "sk-live-12345678")
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.baseURL, "")
        XCTAssertEqual(
            viewModel.codexConfigEditorDraft?.modelProvider,
            ProviderUsageEngine.codexDefaultModelProvider
        )
    }

    func testBDD_GivenRelayAccount_WhenEditingFromCardMenu_ThenOpensConfigEditorSheetWithRelayFields() async throws {
        let root = try makeTempDirectory()
        let manager = CodexAuthManager(rootURL: root)
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("skills", isDirectory: true).path,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let relay = CodexAuthManager.ConfiguredRelay(
            baseURL: "https://relay.example.com/v1",
            modelProvider: "jobmd"
        )
        let account = try await manager.addConfiguredAccount(
            name: "Relay",
            apiKey: "rk-live-12345678",
            relay: relay
        )
        let viewModel = ProviderUsageEngine(provider: provider, codexAuthManager: manager)
        viewModel.codexAccounts = [account]
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(
            cardKind: .relayProfile,
            relayBaseURL: relay.baseURL,
            relayModelProvider: relay.modelProvider
        )

        viewModel.editCodexAccountAuthJSON(id: account.id)

        XCTAssertTrue(viewModel.isShowingCodexConfigEditor)
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.mode, .edit(accountID: account.id))
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.apiKey, "rk-live-12345678")
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.baseURL, relay.baseURL)
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.modelProvider, relay.modelProvider)
    }

    func testBDD_GivenRelayDraftWithQueryParams_WhenSaving_ThenManagedSnapshotPreservesThem() async throws {
        let root = try makeTempDirectory()
        let manager = CodexAuthManager(rootURL: root)
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("skills", isDirectory: true).path,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageEngine(provider: provider, codexAuthManager: manager)

        viewModel.beginNewCodexAPIKeyAccount()
        var draft = try XCTUnwrap(viewModel.codexConfigEditorDraft)
        draft.apiKey = "sk-live-save"
        draft.baseURL = "https://relay.example.com/v1"
        draft.modelProvider = "azure"
        draft.queryParamsText = "api-version=2025-04-01-preview"
        viewModel.codexConfigEditorDraft = draft

        await viewModel.saveCodexConfigEditor()

        let accounts = try await manager.loadAccounts()
        let account = try XCTUnwrap(accounts.first)
        let authData = try XCTUnwrap(manager.accountAuthData(for: account))
        let authJSON = try JSON(data: authData)
        let relayObject = try XCTUnwrap(authJSON["nolon"]["relay"].dictionaryObject)

        XCTAssertEqual(authJSON["nolon"]["relay"]["query_params"]["api-version"].string, "2025-04-01-preview")
        XCTAssertFalse(relayObject.keys.contains("headers"))
    }

    func testBDD_GivenEditedConfiguredAccount_WhenSavingNewAPIKey_ThenReopeningLoadsUpdatedAPIKey() async throws {
        let root = try makeTempDirectory()
        let manager = CodexAuthManager(rootURL: root)
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("skills", isDirectory: true).path,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-live-old",
            relay: nil
        )
        let viewModel = ProviderUsageEngine(provider: provider, codexAuthManager: manager)
        viewModel.codexAccounts = [account]
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(cardKind: .officialAPIKey)

        viewModel.beginEditCodexConfiguredAccount(id: account.id)
        var draft = try XCTUnwrap(viewModel.codexConfigEditorDraft)
        draft.apiKey = "sk-live-new"
        viewModel.codexConfigEditorDraft = draft

        await viewModel.saveCodexConfigEditor()

        let reloadedAccounts = try await manager.loadAccounts()
        viewModel.codexAccounts = reloadedAccounts
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(cardKind: .officialAPIKey)

        viewModel.beginEditCodexConfiguredAccount(id: account.id)

        XCTAssertEqual(viewModel.codexConfigEditorDraft?.apiKey, "sk-live-new")
    }

    func testBDD_GivenEditedConfiguredAccount_WhenSavingNewAPIKey_ThenImmediateReopenUsesLocalPatchedState() async throws {
        let root = try makeTempDirectory()
        let manager = CodexAuthManager(rootURL: root)
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("skills", isDirectory: true).path,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-live-old",
            relay: nil
        )
        let viewModel = ProviderUsageEngine(provider: provider, codexAuthManager: manager)
        viewModel.codexAccounts = [account]
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(cardKind: .officialAPIKey)

        viewModel.beginEditCodexConfiguredAccount(id: account.id)
        var draft = try XCTUnwrap(viewModel.codexConfigEditorDraft)
        draft.apiKey = "sk-live-immediate"
        viewModel.codexConfigEditorDraft = draft

        await viewModel.saveCodexConfigEditor()
        viewModel.beginEditCodexConfiguredAccount(id: account.id)

        XCTAssertEqual(viewModel.codexConfigEditorDraft?.apiKey, "sk-live-immediate")
    }

    func testBDD_GivenActiveOfficialAPIKeyAccount_WhenSavingNewAPIKey_ThenItRefreshesActiveAuthWithoutRewritingConfig() async throws {
        let root = try makeTempDirectory()
        let providerHome = root.appendingPathComponent("provider-home", isDirectory: true)
        let skillsPath = providerHome.appendingPathComponent("skills", isDirectory: true).path
        try FileManager.default.createDirectory(at: providerHome, withIntermediateDirectories: true)
        try writeConfig(
            to: providerHome.appendingPathComponent("config.toml"),
            content: #"""
            approval_policy = "on-request"
            model = "gpt-5.4"
            """#
        )

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skillsPath,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let manager = CodexAuthManager(rootURL: root)
        let account = try await manager.addConfiguredAccount(
            name: "OpenAI Direct",
            apiKey: "sk-live-old",
            relay: nil
        )
        try await manager.activateAccountAndMarkActive(account, for: provider)

        let configURL = providerHome.appendingPathComponent("config.toml")
        let expectedConfig = try String(contentsOf: configURL, encoding: .utf8)

        let viewModel = ProviderUsageEngine(provider: provider, codexAuthManager: manager)
        viewModel.codexAccounts = [account]
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(cardKind: .officialAPIKey)

        viewModel.beginEditCodexConfiguredAccount(id: account.id)
        var draft = try XCTUnwrap(viewModel.codexConfigEditorDraft)
        draft.apiKey = "sk-live-updated"
        viewModel.codexConfigEditorDraft = draft

        await viewModel.saveCodexConfigEditor()

        let actualConfig = try String(contentsOf: configURL, encoding: .utf8)
        let activeAuthData = try Data(
            contentsOf: providerHome.appendingPathComponent("auth.json")
        )
        let activeAuth = try JSON(data: activeAuthData)

        XCTAssertEqual(actualConfig, expectedConfig)
        XCTAssertEqual(activeAuth["OPENAI_API_KEY"].string, "sk-live-updated")
    }

    func testBDD_GivenActiveRelayAccount_WhenSavingNewBaseURL_ThenItRewritesManagedConfig() async throws {
        let root = try makeTempDirectory()
        let providerHome = root.appendingPathComponent("provider-home", isDirectory: true)
        let skillsPath = providerHome.appendingPathComponent("skills", isDirectory: true).path
        try FileManager.default.createDirectory(at: providerHome, withIntermediateDirectories: true)
        try writeConfig(
            to: providerHome.appendingPathComponent("config.toml"),
            content: #"""
            approval_policy = "on-request"
            model_provider = "jobmd"

            [model_providers.jobmd]
            name = "jobmd"
            base_url = "https://relay.example.com/v1"
            requires_openai_auth = true
            wire_api = "responses"
            """#
        )

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skillsPath,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let manager = CodexAuthManager(rootURL: root)
        let account = try await manager.addConfiguredAccount(
            name: "Relay",
            apiKey: "rk-live-old",
            relay: CodexAuthManager.ConfiguredRelay(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "jobmd"
            )
        )
        try await manager.activateAccountAndMarkActive(account, for: provider)

        let viewModel = ProviderUsageEngine(provider: provider, codexAuthManager: manager)
        viewModel.codexAccounts = [account]
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(
            cardKind: .relayProfile,
            relayBaseURL: "https://relay.example.com/v1",
            relayModelProvider: "jobmd"
        )

        viewModel.beginEditCodexConfiguredAccount(id: account.id)
        var draft = try XCTUnwrap(viewModel.codexConfigEditorDraft)
        draft.baseURL = "https://relay-updated.example.com/v1"
        viewModel.codexConfigEditorDraft = draft

        await viewModel.saveCodexConfigEditor()

        let config = try String(
            contentsOf: providerHome.appendingPathComponent("config.toml"),
            encoding: .utf8
        )

        XCTAssertTrue(config.contains(#"base_url = "https://relay-updated.example.com/v1""#))
        XCTAssertFalse(config.contains(#"base_url = "https://relay.example.com/v1""#))
    }

    func testBDD_GivenChatGPTSnapshot_WhenEditingAuthJSON_ThenDoesNotPresentConfigEditorSheet() async throws {
        let root = try makeTempDirectory()
        let manager = CodexAuthManager(rootURL: root)
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("skills", isDirectory: true).path,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = try await manager.addAccount(
            name: "ChatGPT",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"}}"#
        )
        let viewModel = ProviderUsageEngine(provider: provider, codexAuthManager: manager)
        viewModel.codexAccounts = [account]
        viewModel.codexAccountSummaries[account.id] = CodexAuthSummary(cardKind: .chatgptAccount)

        viewModel.editCodexAccountAuthJSON(id: account.id)

        XCTAssertFalse(viewModel.isShowingCodexConfigEditor)
        XCTAssertNil(viewModel.codexConfigEditorDraft)
    }

    func testBDD_GivenNewConfigEditor_WhenOpening_ThenLoadsModelProviderOptionsFromConfigFile() throws {
        let root = try makeTempDirectory()
        let providerHome = root.appendingPathComponent("provider-home", isDirectory: true)
        let skillsPath = providerHome.appendingPathComponent("skills", isDirectory: true).path
        let homePath = root.appendingPathComponent("home", isDirectory: true).path
        try FileManager.default.createDirectory(at: providerHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: homePath).appendingPathComponent(".codex", isDirectory: true),
            withIntermediateDirectories: true
        )
        try writeConfig(
            to: providerHome.appendingPathComponent("config.toml"),
            content: #"""
            model_provider = "jobmd"

            [model_providers.jobmd]
            name = "jobmd"
            base_url = "https://relay.example.com/v1"

            [model_providers.fallback]
            name = "fallback"
            base_url = "https://fallback.example.com/v1"
            """#
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

        XCTAssertEqual(viewModel.codexConfigEditorModelProviderOptions, ["nolon", "jobmd", "fallback"])
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.modelProvider, ProviderUsageEngine.codexDefaultModelProvider)
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.baseURL, "")
        XCTAssertEqual(viewModel.codexConfigEditorDraft?.apiKey, "")
    }

    func testBDD_GivenEditConfigEditor_WhenCurrentProviderNotInConfig_ThenCurrentProviderIsKeptInOptions() throws {
        let root = try makeTempDirectory()
        let providerHome = root.appendingPathComponent("provider-home", isDirectory: true)
        let skillsPath = providerHome.appendingPathComponent("skills", isDirectory: true).path
        let homePath = root.appendingPathComponent("home", isDirectory: true).path
        try FileManager.default.createDirectory(at: providerHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: homePath).appendingPathComponent(".codex", isDirectory: true),
            withIntermediateDirectories: true
        )
        try writeConfig(
            to: providerHome.appendingPathComponent("config.toml"),
            content: #"""
            model_provider = "jobmd"

            [model_providers.jobmd]
            name = "jobmd"
            base_url = "https://relay.example.com/v1"
            """#
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
            ["custom-provider", "jobmd"]
        )
    }

    func testBDD_GivenBlankModelProvider_WhenResolving_ThenFallsBackToNolon() {
        XCTAssertEqual(
            ProviderUsageEngine.resolvedCodexModelProvider("   "),
            ProviderUsageEngine.codexDefaultModelProvider
        )
    }

    func testBDD_GivenExplicitModelProvider_WhenResolving_ThenKeepsTrimmedValue() {
        XCTAssertEqual(
            ProviderUsageEngine.resolvedCodexModelProvider("  relay-prod  "),
            "relay-prod"
        )
    }

    func testBDD_GivenLegacyRelayAccountMissingProvider_WhenActivatingWithMatchingCurrentConfig_ThenBackfillsProviderIntoSnapshot() async throws {
        let root = try makeTempDirectory()
        let providerHome = root.appendingPathComponent("provider-home", isDirectory: true)
        let skillsPath = providerHome.appendingPathComponent("skills", isDirectory: true).path
        try FileManager.default.createDirectory(at: providerHome, withIntermediateDirectories: true)
        try writeConfig(
            to: providerHome.appendingPathComponent("config.toml"),
            content: #"""
            approval_policy = "on-request"
            model_provider = "jobmd"

            [model_providers.jobmd]
            name = "jobmd"
            base_url = "https://relay.example.com/v1"
            requires_openai_auth = true
            wire_api = "responses"
            """#
        )

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: skillsPath,
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let manager = CodexAuthManager(rootURL: root)
        let account = try await manager.addAccount(
            name: "Legacy Relay",
            authJSONString: #"""
            {
              "auth_mode": "apikey",
              "OPENAI_API_KEY": "rk-live-12345678",
              "nolon": {
                "relay": {
                  "base_url": "https://relay.example.com/v1"
                }
              }
            }
            """#
        )

        try await manager.activateAccountAndMarkActive(account, for: provider)

        let persistedConfig = try String(
            contentsOf: providerHome.appendingPathComponent("config.toml"),
            encoding: .utf8
        )
        XCTAssertTrue(persistedConfig.contains(#"model_provider = "jobmd""#))
        XCTAssertTrue(persistedConfig.contains(#"[model_providers.jobmd]"#))

        let repairedData = try XCTUnwrap(manager.accountAuthData(for: account))
        let repairedJSON = try JSON(data: repairedData)
        XCTAssertEqual(repairedJSON["nolon"]["relay"]["model_provider"].string, "jobmd")
        XCTAssertEqual(repairedJSON["base_url"].string, "https://relay.example.com/v1")
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

    private func writeConfig(to fileURL: URL, content: String) throws {
        try Data((content + "\n").utf8).write(to: fileURL, options: .atomic)
    }
}
