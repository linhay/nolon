import XCTest
import STFilePath
import NolonResourceKit
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

private final class CopyTextSink: @unchecked Sendable {
    var value: String?
}

private final class UUIDSink: @unchecked Sendable {
    var value: UUID?
}

private final class URLSink: @unchecked Sendable {
    var value: URL?
}

@MainActor
final class NolonAccountsViewModelTests: XCTestCase {
    func testBDD_GivenAccountsThemeTokens_WhenComparingLightDarkValues_ThenLightModeUsesDedicatedPalette() {
        XCTAssertNotEqual(NolonAccountsThemeTokens.pageBackgroundLight, NolonAccountsThemeTokens.pageBackgroundDark)
        XCTAssertNotEqual(NolonAccountsThemeTokens.panelBackgroundLight, NolonAccountsThemeTokens.panelBackgroundDark)
        XCTAssertEqual(NolonAccountsThemeTokens.pageBackgroundLight, 0xF5F5F7)
        XCTAssertEqual(NolonAccountsThemeTokens.panelBackgroundLight, 0xFFFFFF)
    }

    func testBDD_GivenCodexXcodeProvider_WhenResolvingUsageProvider_ThenReturnsNil() {
        let provider = Provider(
            id: "codex-xcode",
            kind: .vendor,
            name: "Codex (Xcode)",
            defaultSkillsPath: "/tmp/codex-xcode/skills",
            workflowPath: "/tmp/codex-xcode/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codexXcode.rawValue
        )

        let mapped = NolonAccountsViewModel.mapUsageProvider(for: provider)

        XCTAssertNil(mapped)
    }

    func testBDD_GivenGeminiAndAntigravityProviders_WhenResolvingUsageProvider_ThenReturnsMatchingUsageProvider() {
        let gemini = Provider(
            id: "gemini",
            kind: .vendor,
            name: "Gemini",
            defaultSkillsPath: "/tmp/gemini/skills",
            workflowPath: "/tmp/gemini/workflows",
            vendorCategory: .original,
            templateId: ProviderTemplate.gemini.rawValue
        )
        let antigravity = Provider(
            id: "antigravity",
            kind: .vendor,
            name: "Antigravity",
            defaultSkillsPath: "/tmp/antigravity/skills",
            workflowPath: "/tmp/antigravity/workflows",
            vendorCategory: .integrated,
            templateId: ProviderTemplate.antigravity.rawValue
        )

        XCTAssertEqual(NolonAccountsViewModel.mapUsageProvider(for: gemini), .gemini)
        XCTAssertEqual(NolonAccountsViewModel.mapUsageProvider(for: antigravity), .antigravity)
    }

    func testBDD_GivenUsageOutcomes_WhenBuildingAggregateSummary_ThenReturnsTotalSuccessFailureAndLatestTimestamp() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )

        let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDate = Date(timeIntervalSince1970: 1_700_100_000)

        let successUsage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: "dev@example.com", accountOrganization: "Org", loginMethod: "oauth", plan: "pro"),
            primary: RateWindow(usedPercent: 42),
            secondary: nil,
            tertiary: nil,
            updatedAt: secondDate
        )
        let successResult = ProviderFetchResult(
            usage: successUsage,
            credits: nil,
            cost: nil,
            sourceLabel: "CLI",
            fetchKind: .cli,
            strategyKind: .direct
        )
        let successOutcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .default,
            outcome: ProviderFetchOutcome(fetchKind: .cli, result: .success(successResult))
        )

        let failureOutcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .default,
            outcome: ProviderFetchOutcome(fetchKind: .cli, result: .failure(ProviderUsageError.missingAccount(.codex)))
        )

        let aggregate = NolonAccountsViewModel.makeUsageSummary(
            provider: provider,
            usageProvider: .codex,
            outcomes: [successOutcome, failureOutcome, ProviderAccountUsageOutcome(
                provider: .codex,
                account: .default,
                outcome: ProviderFetchOutcome(
                    fetchKind: .cli,
                    result: .success(
                        ProviderFetchResult(
                            usage: UsageSnapshot(
                                identity: nil,
                                primary: nil,
                                secondary: nil,
                                tertiary: nil,
                                updatedAt: firstDate
                            ),
                            credits: nil,
                            cost: nil,
                            sourceLabel: "CLI",
                            fetchKind: .cli,
                            strategyKind: .direct
                        )
                    )
                )
            )]
        )

        XCTAssertNotNil(aggregate)
        XCTAssertEqual(aggregate?.totalCount, 3)
        XCTAssertEqual(aggregate?.successCount, 2)
        XCTAssertEqual(aggregate?.failureCount, 1)
        XCTAssertEqual(aggregate?.latestUpdatedAt, secondDate)
        XCTAssertEqual(aggregate?.accountEmail, "dev@example.com")
        XCTAssertEqual(aggregate?.primaryUsedPercent, 42)
    }

    func testBDD_GivenMultipleAccountOutcomes_WhenBuildingAccountSummaries_ThenReturnsAllAccountsPerProvider() {
        let now = Date(timeIntervalSince1970: 1_700_200_000)
        let tokenID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

        let defaultSuccess = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .success(
                    ProviderFetchResult(
                        usage: UsageSnapshot(
                            identity: UsageIdentity(
                                accountEmail: "default@example.com",
                                accountOrganization: nil,
                                loginMethod: "oauth",
                                plan: "pro"
                            ),
                            primary: RateWindow(usedPercent: 37),
                            secondary: nil,
                            tertiary: nil,
                            updatedAt: now
                        ),
                        credits: nil,
                        cost: nil,
                        sourceLabel: "CLI",
                        fetchKind: .cli,
                        strategyKind: .direct
                    )
                )
            )
        )

        let tokenFailure = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                ProviderTokenAccount(
                    id: tokenID,
                    label: "Team Token",
                    token: "redacted",
                    addedAt: now.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .failure(ProviderUsageError.authExpired(.codex))
            )
        )

        let summaries = NolonAccountsViewModel.makeAccountSummaries(
            outcomes: [defaultSuccess, tokenFailure]
        )

        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries[0].id, "codex.default")
        XCTAssertEqual(summaries[0].accountEmail, "default@example.com")
        XCTAssertEqual(summaries[0].successCount, 1)
        XCTAssertEqual(summaries[0].failureCount, 0)
        XCTAssertNil(summaries[0].errorMessage)

        XCTAssertEqual(summaries[1].id, "codex.\(tokenID.uuidString)")
        XCTAssertEqual(summaries[1].accountLabel, "Team Token")
        XCTAssertEqual(summaries[1].successCount, 0)
        XCTAssertEqual(summaries[1].failureCount, 1)
        XCTAssertNotNil(summaries[1].errorMessage)
        XCTAssertFalse(summaries[0].isSnapshotOnly)
    }

    func testBDD_GivenCodexSnapshotAccounts_WhenMergingWithLiveUsage_ThenReturnsAllSnapshotAccountsAndKeepsActiveUsage() {
        let activeID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let secondaryID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let now = Date(timeIntervalSince1970: 1_700_300_000)

        let live = NolonAccountsViewModel.AccountUsageSummary(
            id: "codex.default",
            accountLabel: "Default",
            accountEmail: "active@example.com",
            plan: "pro",
            totalCount: 1,
            successCount: 1,
            failureCount: 0,
            latestUpdatedAt: now,
            primaryUsedPercent: 22,
            errorMessage: nil,
            isSnapshotOnly: false
        )

        let accounts = [
            CodexAuthAccount(id: activeID, name: "Work", createdAt: now, relativeAuthPath: "auth/work.json"),
            CodexAuthAccount(id: secondaryID, name: "Side", createdAt: now, relativeAuthPath: "auth/side.json")
        ]

        let summaries: [UUID: CodexAuthSummary] = [
            activeID: CodexAuthSummary(email: "active@example.com", plan: "pro", cardKind: .chatgptAccount),
            secondaryID: CodexAuthSummary(email: "side@example.com", plan: "free", cardKind: .chatgptAccount)
        ]

        let merged = NolonAccountsViewModel.mergeCodexSnapshotAccounts(
            liveSummaries: [live],
            accounts: accounts,
            summaries: summaries,
            activeAccountID: activeID,
            providerAuthSummary: nil
        )

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].id, activeID.uuidString)
        XCTAssertEqual(merged[0].accountEmail, "active@example.com")
        XCTAssertEqual(merged[0].primaryUsedPercent, 22)
        XCTAssertFalse(merged[0].isSnapshotOnly)

        XCTAssertEqual(merged[1].id, secondaryID.uuidString)
        XCTAssertEqual(merged[1].accountEmail, "side@example.com")
        XCTAssertEqual(merged[1].totalCount, 0)
        XCTAssertTrue(merged[1].isSnapshotOnly)
    }

    func testBDD_GivenInactiveCodexSnapshotCard_WhenBuildingAccountCards_ThenIncludesActivateAndAuthJSONMenus() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let viewModel = NolonAccountsViewModel(settings: ProviderSettings())
        viewModel.accountSummariesByProviderID[provider.id] = [
            .init(
                id: id.uuidString,
                accountLabel: "Work",
                accountEmail: "work@example.com",
                plan: "plus",
                totalCount: 0,
                successCount: 0,
                failureCount: 0,
                latestUpdatedAt: Date(timeIntervalSince1970: 1_700_300_000),
                primaryUsedPercent: nil,
                errorMessage: nil,
                isSnapshotOnly: true
            )
        ]

        let cards = viewModel.accountCards(for: provider)

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].presentation.selectionStyle, .neutral)
        XCTAssertEqual(cards[0].tapBehavior, .activate)
        XCTAssertTrue(cards[0].primaryActions.isEmpty)
        XCTAssertEqual(cards[0].menuActions.map(\.actionID), [.copyAccountID, .copyAuthPath, .copyAuthJSON, .editAuthJSON])
    }

    func testBDD_GivenActiveCodexSnapshotCard_WhenBuildingAccountCards_ThenShowsActiveStateWithoutActivateAction() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let viewModel = NolonAccountsViewModel(settings: ProviderSettings())
        viewModel.accountSummariesByProviderID[provider.id] = [
            .init(
                id: id.uuidString,
                accountLabel: "Work",
                accountEmail: "work@example.com",
                plan: "plus",
                totalCount: 1,
                successCount: 1,
                failureCount: 0,
                latestUpdatedAt: Date(timeIntervalSince1970: 1_700_300_000),
                primaryUsedPercent: 20,
                errorMessage: nil,
                isSnapshotOnly: false
            )
        ]
        viewModel.activeCodexAccountIDByProviderID[provider.id] = id

        let cards = viewModel.accountCards(for: provider)

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].presentation.selectionStyle, .active)
        XCTAssertTrue(cards[0].primaryActions.isEmpty)
        XCTAssertEqual(cards[0].tapBehavior, .openProvider)
    }

    func testBDD_GivenCodexSnapshotID_WhenCopyingAuthPath_ThenPasteboardWriterReceivesSnapshotPath() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-accounts-copy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"}}"#
        )

        let sink = CopyTextSink()
        let viewModel = NolonAccountsViewModel(
            settings: ProviderSettings(),
            codexAuthManager: service,
            copyTextAction: { text in
                sink.value = text
            }
        )

        await viewModel.copyCodexAccountPath(account.id)

        let expected = service.accountAuthFile(relativeAuthPath: account.relativeAuthPath).url.path
        XCTAssertEqual(sink.value, expected)
    }

    func testBDD_GivenCodexSnapshotID_WhenCopyingAuthJSON_ThenPasteboardWriterReceivesRawJSON() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-accounts-copy-auth-json-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"}}"#
        )

        let sink = CopyTextSink()
        let viewModel = NolonAccountsViewModel(
            settings: ProviderSettings(),
            codexAuthManager: service,
            copyTextAction: { text in
                sink.value = text
            }
        )

        await viewModel.copyCodexAccountAuthJSON(account.id)

        let file = service.accountAuthFile(relativeAuthPath: account.relativeAuthPath)
        let expected = try file.read()
        XCTAssertEqual(sink.value, expected)
    }

    func testBDD_GivenCodexSnapshotID_WhenEditingAuthJSON_ThenOpenActionReceivesAuthFileURL() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-accounts-edit-auth-json-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"}}"#
        )

        let sink = URLSink()
        let viewModel = NolonAccountsViewModel(
            settings: ProviderSettings(),
            codexAuthManager: service,
            openURLAction: { url in
                sink.value = url
            }
        )

        await viewModel.editCodexAccountAuthJSON(account.id)

        let expected = service.accountAuthFile(relativeAuthPath: account.relativeAuthPath).url
        XCTAssertEqual(sink.value, expected)
    }

    func testBDD_GivenCodexSnapshotID_WhenActivatingFromAccountsPage_ThenUsesActivationCoordinatorClosure() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-accounts-activate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"}}"#
        )
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("provider/skills").path,
            workflowPath: root.appendingPathComponent("provider/prompts").path,
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let sink = UUIDSink()
        let viewModel = NolonAccountsViewModel(
            settings: ProviderSettings(),
            codexAuthManager: service,
            codexActivateAction: { account, _ in
                sink.value = account.id
            }
        )

        await viewModel.activateCodexAccount(id: account.id, for: provider)

        XCTAssertEqual(sink.value, account.id)
    }

    func testBDD_GivenPiAuthPayloadWithRootEmail_WhenParsing_ThenReturnsAvailableStatusWithEmail() throws {
        let data = try XCTUnwrap(
            """
            {
              "email": "pi@example.com"
            }
            """.data(using: .utf8)
        )

        let status = PiAuthStatusParser.parse(data)

        XCTAssertEqual(status, .available(email: "pi@example.com"))
    }

    func testBDD_GivenPiAuthPayloadWithNestedUserEmail_WhenParsing_ThenReturnsAvailableStatusWithEmail() throws {
        let data = try XCTUnwrap(
            """
            {
              "user": {
                "email": "nested@example.com"
              }
            }
            """.data(using: .utf8)
        )

        let status = PiAuthStatusParser.parse(data)

        XCTAssertEqual(status, .available(email: "nested@example.com"))
    }

    func testBDD_GivenInvalidPiAuthPayload_WhenParsing_ThenReturnsInvalidStatus() throws {
        let data = try XCTUnwrap("not-json".data(using: .utf8))

        let status = PiAuthStatusParser.parse(data)

        XCTAssertEqual(status, .invalid)
    }

    func testBDD_GivenClaudeAccountRecord_WhenMappingCard_ThenBaseURLOnlyAppearsInSubtitle() {
        let updatedAt = Date(timeIntervalSince1970: 1_700_400_000)
        let account = ClaudeAccount(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            name: "Workspace",
            credentialType: .authToken,
            credentialValue: "token",
            baseURL: "https://claude.example.com",
            source: .ccSwitch,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            lastValidatedAt: updatedAt,
            lastValidationStatus: true
        )

        let record = AccountRecordBuilder.claude(
            providerName: "Claude",
            account: account,
            isActive: true
        )
        let card = AccountCardViewDataMapper.map(record: record)

        XCTAssertEqual(card.header.subtitle, "https://claude.example.com")
        XCTAssertTrue(card.detailRows.isEmpty)
        XCTAssertEqual(
            card.header.badge?.text,
            NSLocalizedString("accounts.summary.active", value: "已激活", comment: "Active badge")
        )
    }

    func testBDD_GivenGeminiAccountRecord_WhenMappingCard_ThenInactiveCardShowsMetadataRows() {
        let createdAt = Date(timeIntervalSince1970: 1_700_500_000)
        let account = GeminiAuthAccount(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            providerID: .gemini,
            name: "Gemini Personal",
            method: .oauthPersonal,
            createdAt: createdAt,
            lastUsedAt: nil,
            lastLoginAt: createdAt,
            email: "gemini@example.com",
            project: "alpha",
            location: "us-central1",
            runtimeHomeRelativePath: ".gemini/work"
        )

        let record = AccountRecordBuilder.gemini(
            providerName: "Gemini",
            account: account,
            isActive: false,
            quota: nil
        )
        let card = AccountCardViewDataMapper.map(record: record)

        XCTAssertEqual(card.header.subtitle, "gemini@example.com • alpha")
        XCTAssertEqual(card.header.badge, nil)
        guard case let .rows(rows) = card.body else {
            return XCTFail("Expected rows body for inactive Gemini account")
        }
        XCTAssertEqual(rows.map(\.id), ["method", "project"])
        XCTAssertEqual(card.detailRows.first?.value, ".gemini/work")
    }
}
