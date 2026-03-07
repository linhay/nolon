import XCTest
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

@MainActor
final class CodexAccountDisplaySectionsTests: XCTestCase {
    func testBDD_GivenDefaultCodexDisplayOptions_WhenInitialized_ThenUsesTypeGroupingAndRemainingCreditsSort() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())

        XCTAssertEqual(viewModel.codexAccountGroupingOption, .typeInfo)
        XCTAssertEqual(viewModel.codexAccountSortOption, .remainingCredits)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .descending)
        XCTAssertEqual(viewModel.codexPrimaryHeaderActions, [.refreshAll, .login, .importAuth])
    }

    func testBDD_GivenMixedCardKinds_WhenGroupingByTypeInfo_ThenChatGPTUsesPlanAndConfigsUseProvider() {
        let chatgptAccount = CodexAuthAccount(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Personal",
            createdAt: Date(timeIntervalSince1970: 100),
            relativeAuthPath: "auth/personal.json"
        )
        let apiKeyAccount = CodexAuthAccount(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "OpenAI Direct",
            createdAt: Date(timeIntervalSince1970: 200),
            relativeAuthPath: "auth/openai-direct.json"
        )
        let relayAccount = CodexAuthAccount(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Work Relay",
            createdAt: Date(timeIntervalSince1970: 300),
            relativeAuthPath: "auth/work-relay.json"
        )

        let sections = ProviderUsageViewModel.makeCodexAccountDisplaySections(
            accounts: [chatgptAccount, apiKeyAccount, relayAccount],
            outcomes: [
                Self.makeOutcome(account: chatgptAccount, label: "Personal", remaining: 8),
                Self.makeOutcome(account: apiKeyAccount, label: "OpenAI Direct", remaining: 6),
                Self.makeOutcome(account: relayAccount, label: "Work Relay", remaining: 7)
            ],
            summaries: [
                chatgptAccount.id: CodexAuthSummary(plan: "Plus", name: "Personal", cardKind: .chatgptAccount),
                apiKeyAccount.id: CodexAuthSummary(name: "OpenAI Direct", cardKind: .officialAPIKey),
                relayAccount.id: CodexAuthSummary(name: "Work Relay", cardKind: .relayProfile, relayModelProvider: "relay")
            ],
            grouping: .typeInfo,
            sorting: .remainingCredits
        )

        XCTAssertEqual(sections.map(\.title), ["OpenAI", "Plus", "Relay"])
        XCTAssertEqual(sections.first?.items.first?.displayName, "OpenAI Direct")
    }

    func testBDD_GivenGroupingDisabled_WhenBuildingDisplaySections_ThenReturnsSingleUntitledSection() {
        let account = CodexAuthAccount(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Flat",
            createdAt: Date(timeIntervalSince1970: 100),
            relativeAuthPath: "auth/flat.json"
        )

        let sections = ProviderUsageViewModel.makeCodexAccountDisplaySections(
            accounts: [account],
            outcomes: [Self.makeOutcome(account: account, label: "Flat", remaining: nil)],
            summaries: [account.id: CodexAuthSummary(name: "Flat", cardKind: .officialAPIKey)],
            grouping: .none,
            sorting: .name
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertNil(sections[0].title)
        XCTAssertEqual(sections[0].items.count, 1)
    }

    func testBDD_GivenRemainingCreditsSort_WhenBuildingSections_ThenOrdersDescendingBeforeMissingCredits() {
        let high = CodexAuthAccount(id: UUID(), name: "High", createdAt: .distantPast, relativeAuthPath: "auth/high.json")
        let low = CodexAuthAccount(id: UUID(), name: "Low", createdAt: .distantPast, relativeAuthPath: "auth/low.json")
        let none = CodexAuthAccount(id: UUID(), name: "None", createdAt: .distantPast, relativeAuthPath: "auth/none.json")

        let sections = ProviderUsageViewModel.makeCodexAccountDisplaySections(
            accounts: [high, low, none],
            outcomes: [
                Self.makeOutcome(account: high, label: "High", remaining: 20),
                Self.makeOutcome(account: low, label: "Low", remaining: 5),
                Self.makeOutcome(account: none, label: "None", remaining: nil)
            ],
            summaries: [
                high.id: CodexAuthSummary(cardKind: .officialAPIKey),
                low.id: CodexAuthSummary(cardKind: .officialAPIKey),
                none.id: CodexAuthSummary(cardKind: .officialAPIKey)
            ],
            grouping: .none,
            sorting: .remainingCredits,
            sortDirection: .descending
        )

        XCTAssertEqual(sections[0].items.map(\.displayName), ["High", "Low", "None"])
    }

    func testBDD_GivenQuotaWindowRemainingSort_WhenBuildingSections_ThenOrdersBySelectedWindowDescending() {
        let high = CodexAuthAccount(id: UUID(), name: "High", createdAt: .distantPast, relativeAuthPath: "auth/high.json")
        let low = CodexAuthAccount(id: UUID(), name: "Low", createdAt: .distantPast, relativeAuthPath: "auth/low.json")
        let missing = CodexAuthAccount(id: UUID(), name: "Missing", createdAt: .distantPast, relativeAuthPath: "auth/missing.json")

        let sections = ProviderUsageViewModel.makeCodexAccountDisplaySections(
            accounts: [high, low, missing],
            outcomes: [
                Self.makeOutcome(
                    account: high,
                    label: "High",
                    remaining: nil,
                    primaryWindow: .init(usedPercent: 20, windowMinutes: 60)
                ),
                Self.makeOutcome(
                    account: low,
                    label: "Low",
                    remaining: nil,
                    primaryWindow: .init(usedPercent: 60, windowMinutes: 60)
                ),
                Self.makeOutcome(account: missing, label: "Missing", remaining: nil)
            ],
            summaries: [
                high.id: CodexAuthSummary(cardKind: .officialAPIKey),
                low.id: CodexAuthSummary(cardKind: .officialAPIKey),
                missing.id: CodexAuthSummary(cardKind: .officialAPIKey)
            ],
            grouping: .none,
            sorting: .quotaWindowRemaining(windowMinutes: 60),
            sortDirection: .descending
        )

        XCTAssertEqual(sections[0].items.map(\.displayName), ["High", "Low", "Missing"])
    }

    func testBDD_GivenExpiryTimeSort_WhenBuildingSections_ThenOrdersByEarliestResetFirst() {
        let high = CodexAuthAccount(id: UUID(), name: "High", createdAt: .distantPast, relativeAuthPath: "auth/high-window.json")
        let low = CodexAuthAccount(id: UUID(), name: "Low", createdAt: .distantPast, relativeAuthPath: "auth/low-window.json")
        let missing = CodexAuthAccount(id: UUID(), name: "Missing", createdAt: .distantPast, relativeAuthPath: "auth/missing-window.json")

        let sections = ProviderUsageViewModel.makeCodexAccountDisplaySections(
            accounts: [high, low, missing],
            outcomes: [
                Self.makeOutcome(
                    account: high,
                    label: "High",
                    remaining: nil,
                    primaryWindow: .init(usedPercent: 10, resetsAt: Date(timeIntervalSince1970: 300), windowMinutes: 1440)
                ),
                Self.makeOutcome(
                    account: low,
                    label: "Low",
                    remaining: nil,
                    primaryWindow: .init(usedPercent: 80, resetsAt: Date(timeIntervalSince1970: 100), windowMinutes: 1440)
                ),
                Self.makeOutcome(account: missing, label: "Missing", remaining: nil)
            ],
            summaries: [
                high.id: CodexAuthSummary(cardKind: .officialAPIKey),
                low.id: CodexAuthSummary(cardKind: .officialAPIKey),
                missing.id: CodexAuthSummary(cardKind: .officialAPIKey)
            ],
            grouping: .none,
            sorting: .expiryTime,
            sortDirection: .ascending
        )

        XCTAssertEqual(sections[0].items.map(\.displayName), ["Low", "High", "Missing"])
    }

    func testBDD_GivenExpiryTimeSortDescending_WhenBuildingSections_ThenOrdersByLatestResetFirst() {
        let high = CodexAuthAccount(id: UUID(), name: "High", createdAt: .distantPast, relativeAuthPath: "auth/high-window.json")
        let low = CodexAuthAccount(id: UUID(), name: "Low", createdAt: .distantPast, relativeAuthPath: "auth/low-window.json")

        let sections = ProviderUsageViewModel.makeCodexAccountDisplaySections(
            accounts: [high, low],
            outcomes: [
                Self.makeOutcome(
                    account: high,
                    label: "High",
                    remaining: nil,
                    primaryWindow: .init(usedPercent: 10, resetsAt: Date(timeIntervalSince1970: 300), windowMinutes: 1440)
                ),
                Self.makeOutcome(
                    account: low,
                    label: "Low",
                    remaining: nil,
                    primaryWindow: .init(usedPercent: 80, resetsAt: Date(timeIntervalSince1970: 100), windowMinutes: 1440)
                )
            ],
            summaries: [
                high.id: CodexAuthSummary(cardKind: .officialAPIKey),
                low.id: CodexAuthSummary(cardKind: .officialAPIKey)
            ],
            grouping: .none,
            sorting: .expiryTime,
            sortDirection: .descending
        )

        XCTAssertEqual(sections[0].items.map(\.displayName), ["High", "Low"])
    }

    func testBDD_GivenRelayProviderNamesWithDifferentCase_WhenGrouping_ThenSharesSameSection() {
        let first = CodexAuthAccount(id: UUID(), name: "Relay Lower", createdAt: .distantPast, relativeAuthPath: "auth/relay-lower.json")
        let second = CodexAuthAccount(id: UUID(), name: "Relay Upper", createdAt: .distantPast, relativeAuthPath: "auth/relay-upper.json")

        let sections = ProviderUsageViewModel.makeCodexAccountDisplaySections(
            accounts: [first, second],
            outcomes: [
                Self.makeOutcome(account: first, label: "Relay Lower", remaining: 20),
                Self.makeOutcome(account: second, label: "Relay Upper", remaining: 10)
            ],
            summaries: [
                first.id: CodexAuthSummary(cardKind: .relayProfile, relayModelProvider: "relay"),
                second.id: CodexAuthSummary(cardKind: .relayProfile, relayModelProvider: "RELAY")
            ],
            grouping: .typeInfo,
            sorting: .remainingCredits,
            sortDirection: .descending
        )

        XCTAssertEqual(sections.map(\.title), ["Relay"])
        XCTAssertEqual(sections[0].items.count, 2)
    }

    func testBDD_GivenSelectingCurrentSortOption_WhenTappedAgain_ThenTogglesDirection() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())

        XCTAssertEqual(viewModel.codexAccountSortOption, .remainingCredits)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .descending)

        viewModel.selectCodexSortOption(.remainingCredits)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .ascending)

        viewModel.selectCodexSortOption(.remainingCredits)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .descending)
    }

    func testBDD_GivenSelectingDifferentSortOption_WhenTapped_ThenUsesThatOptionDefaultDirection() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())

        viewModel.selectCodexSortOption(.name)
        XCTAssertEqual(viewModel.codexAccountSortOption, .name)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .ascending)

        viewModel.selectCodexSortOption(.expiryTime)
        XCTAssertEqual(viewModel.codexAccountSortOption, .expiryTime)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .ascending)

        viewModel.selectCodexSortOption(.quotaWindowRemaining(windowMinutes: 60))
        XCTAssertEqual(viewModel.codexAccountSortOption, .quotaWindowRemaining(windowMinutes: 60))
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .descending)
    }

    func testBDD_GivenPreviousSortDirectionWasToggled_WhenSwitchingAwayAndBack_ThenNonSelectedSortResetsToDefaultDirection() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())

        viewModel.selectCodexSortOption(.name)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .ascending)

        viewModel.selectCodexSortOption(.name)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .descending)

        viewModel.selectCodexSortOption(.expiryTime)
        XCTAssertEqual(viewModel.codexAccountSortOption, .expiryTime)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .ascending)

        viewModel.selectCodexSortOption(.name)
        XCTAssertEqual(viewModel.codexAccountSortOption, .name)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .ascending)
    }

    func testBDD_GivenConfigCardAuthFailure_WhenResolvingDisplayState_ThenDoesNotRequireRelogin() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        let outcome = ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(.init(id: UUID(), label: "Relay", token: "", addedAt: 0, lastUsed: nil)),
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .failure(ProviderUsageError.authExpired(.codex))
            )
        )

        let state = viewModel.displayState(
            accountID: UUID(),
            outcome: outcome,
            summary: CodexAuthSummary(cardKind: .relayProfile)
        )

        XCTAssertEqual(state, .failed)
    }

    func testBDD_GivenRelayActiveCard_WhenResolvingHeaderActions_ThenKeepsLoginImportAlongsideConfigActions() {
        let actions = ProviderUsageViewModel.codexPrimaryHeaderActions(for: .relayProfile)

        XCTAssertEqual(actions, [.refreshAll, .login, .importAuth, .editConfig, .validateConfig])
    }

    func testBDD_GivenSectionID_WhenTogglingCollapse_ThenMembershipFlips() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())

        XCTAssertFalse(viewModel.isCodexSectionCollapsed("OpenAI"))
        viewModel.toggleCodexSection("OpenAI")
        XCTAssertTrue(viewModel.isCodexSectionCollapsed("OpenAI"))
        viewModel.toggleCodexSection("OpenAI")
        XCTAssertFalse(viewModel.isCodexSectionCollapsed("OpenAI"))
    }

    func testBDD_GivenCodexMultiSelectionMode_WhenToggledOff_ThenSelectionsAreCleared() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        let id = UUID()

        viewModel.setCodexMultiSelectionEnabled(true)
        viewModel.toggleCodexAccountSelection(id: id)
        XCTAssertTrue(viewModel.isCodexMultiSelectionEnabled)
        XCTAssertEqual(viewModel.selectedCodexAccountIDs, [id])

        viewModel.setCodexMultiSelectionEnabled(false)

        XCTAssertFalse(viewModel.isCodexMultiSelectionEnabled)
        XCTAssertTrue(viewModel.selectedCodexAccountIDs.isEmpty)
    }

    func testBDD_GivenCodexMultiSelectionMode_WhenSelectingAccounts_ThenExportAvailabilityTracksSelectionCount() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        let first = UUID()
        let second = UUID()

        viewModel.setCodexMultiSelectionEnabled(true)
        viewModel.toggleCodexAccountSelection(id: first)
        viewModel.toggleCodexAccountSelection(id: second)

        XCTAssertEqual(viewModel.selectedCodexAccountIDs, [first, second])
        XCTAssertEqual(viewModel.codexSelectedAccountCount, 2)
        XCTAssertTrue(viewModel.canExportSelectedCodexAccounts)

        viewModel.toggleCodexAccountSelection(id: first)
        viewModel.toggleCodexAccountSelection(id: second)

        XCTAssertEqual(viewModel.codexSelectedAccountCount, 0)
        XCTAssertFalse(viewModel.canExportSelectedCodexAccounts)
    }

    func testBDD_GivenImportCandidates_WhenSelectingAllAndClearing_ThenSelectionCountTracksValidItems() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        viewModel.codexImportCandidates = [
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/a.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/a.json"),
                    sourceGroupID: "/tmp/archive.zip",
                    sourceGroupLabel: "archive.zip",
                    isValid: true,
                    reason: nil,
                    suggestedName: "A",
                    email: nil,
                    authJSONString: "{}"
                ),
                isSelected: false,
                testStatus: .idle,
                testSummary: nil,
                testDetail: nil
            ),
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/b.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/b.json"),
                    sourceGroupID: "/tmp/archive.zip",
                    sourceGroupLabel: "archive.zip",
                    isValid: false,
                    reason: "Invalid UTF-8",
                    suggestedName: nil,
                    email: nil,
                    authJSONString: nil
                ),
                isSelected: false,
                testStatus: .failure,
                testSummary: nil,
                testDetail: nil
            )
        ]

        viewModel.setAllCodexImportCandidatesSelected(true)
        XCTAssertEqual(viewModel.codexSelectedImportCandidateCount, 1)

        viewModel.setAllCodexImportCandidatesSelected(false)
        XCTAssertEqual(viewModel.codexSelectedImportCandidateCount, 0)
    }

    func testBDD_GivenImportCandidates_WhenSelectingWholeGroup_ThenOnlyThatGroupChanges() {
        let viewModel = ProviderUsageViewModel(provider: Self.makeCodexProvider())
        viewModel.codexImportCandidates = [
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/a-1.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/a-1.json"),
                    sourceGroupID: "group-a",
                    sourceGroupLabel: "archive-a.zip",
                    isValid: true,
                    reason: nil,
                    suggestedName: "A1",
                    email: nil,
                    authJSONString: "{}"
                ),
                isSelected: false,
                testStatus: .idle,
                testSummary: nil,
                testDetail: nil
            ),
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/a-2.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/a-2.json"),
                    sourceGroupID: "group-a",
                    sourceGroupLabel: "archive-a.zip",
                    isValid: true,
                    reason: nil,
                    suggestedName: "A2",
                    email: nil,
                    authJSONString: "{}"
                ),
                isSelected: false,
                testStatus: .idle,
                testSummary: nil,
                testDetail: nil
            ),
            .init(
                sourceFileURL: URL(fileURLWithPath: "/tmp/b-1.json"),
                validation: .init(
                    fileURL: URL(fileURLWithPath: "/tmp/b-1.json"),
                    sourceGroupID: "group-b",
                    sourceGroupLabel: "archive-b.zip",
                    isValid: true,
                    reason: nil,
                    suggestedName: "B1",
                    email: nil,
                    authJSONString: "{}"
                ),
                isSelected: false,
                testStatus: .idle,
                testSummary: nil,
                testDetail: nil
            )
        ]

        XCTAssertEqual(viewModel.codexImportCandidateSections.count, 2)

        viewModel.setCodexImportCandidatesSelected(true, sourceGroupID: "group-a")

        XCTAssertEqual(viewModel.codexSelectedImportCandidateCount, 2)
        XCTAssertTrue(viewModel.codexImportCandidates[0].isSelected)
        XCTAssertTrue(viewModel.codexImportCandidates[1].isSelected)
        XCTAssertFalse(viewModel.codexImportCandidates[2].isSelected)

        viewModel.setCodexImportCandidatesSelected(false, sourceGroupID: "group-a")

        XCTAssertEqual(viewModel.codexSelectedImportCandidateCount, 0)
    }

    private static func makeCodexProvider() -> Provider {
        Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
    }

    private static func makeOutcome(
        account: CodexAuthAccount,
        label: String,
        remaining: Double?,
        primaryWindow: RateWindow? = nil,
        secondaryWindow: RateWindow? = nil,
        tertiaryWindow: RateWindow? = nil
    ) -> ProviderAccountUsageOutcome {
        let tokenAccount = ProviderTokenAccount(
            id: account.id,
            label: label,
            token: "",
            addedAt: account.createdAt.timeIntervalSince1970,
            lastUsed: nil
        )
        let usage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: nil, accountOrganization: nil, loginMethod: nil, plan: nil),
            primary: primaryWindow,
            secondary: secondaryWindow,
            tertiary: tertiaryWindow,
            updatedAt: Date()
        )
        let result = ProviderFetchResult(
            usage: usage,
            credits: remaining.map { CreditsSnapshot(remaining: $0, updatedAt: Date()) },
            cost: nil,
            sourceLabel: "CLI",
            fetchKind: .cli,
            strategyKind: .direct
        )
        return ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(tokenAccount),
            outcome: .init(fetchKind: .cli, result: .success(result))
        )
    }
}
