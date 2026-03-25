import XCTest
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonCoreCLIKit
@testable import nolon

@MainActor
final class CodexAccountDisplaySectionsTests: XCTestCase {
    func testBDD_GivenDefaultCodexDisplayOptions_WhenInitialized_ThenUsesTypeGroupingAndRemainingCreditsSort() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())

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

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
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

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
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

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
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

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
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

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
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

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
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

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
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

    func testBDD_GivenHideZeroQuotaEnabled_WhenLongestWindowRemainingIsZero_ThenAccountIsFilteredOut() {
        let zeroLongest = CodexAuthAccount(id: UUID(), name: "Zero Longest", createdAt: .distantPast, relativeAuthPath: "auth/zero-longest.json")
        let availableLongest = CodexAuthAccount(id: UUID(), name: "Available Longest", createdAt: .distantPast, relativeAuthPath: "auth/available-longest.json")
        let missingWindows = CodexAuthAccount(id: UUID(), name: "Missing Windows", createdAt: .distantPast, relativeAuthPath: "auth/missing-windows.json")

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
            accounts: [zeroLongest, availableLongest, missingWindows],
            outcomes: [
                Self.makeOutcome(
                    account: zeroLongest,
                    label: "Zero Longest",
                    remaining: nil,
                    primaryWindow: .init(usedPercent: 20, windowMinutes: 60),
                    secondaryWindow: .init(usedPercent: 100, windowMinutes: 1440)
                ),
                Self.makeOutcome(
                    account: availableLongest,
                    label: "Available Longest",
                    remaining: nil,
                    primaryWindow: .init(usedPercent: 100, windowMinutes: 60),
                    secondaryWindow: .init(usedPercent: 20, windowMinutes: 1440)
                ),
                Self.makeOutcome(
                    account: missingWindows,
                    label: "Missing Windows",
                    remaining: nil
                )
            ],
            summaries: [
                zeroLongest.id: CodexAuthSummary(cardKind: .officialAPIKey),
                availableLongest.id: CodexAuthSummary(cardKind: .officialAPIKey),
                missingWindows.id: CodexAuthSummary(cardKind: .officialAPIKey)
            ],
            grouping: .none,
            sorting: .name,
            hideZeroQuotaAccounts: true
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(Set(sections[0].items.map(\.displayName)), Set(["Available Longest", "Missing Windows"]))
    }

    func testBDD_GivenHideZeroQuotaDisabled_WhenLongestWindowRemainingIsZero_ThenAccountRemainsVisible() {
        let zeroLongest = CodexAuthAccount(id: UUID(), name: "Zero Longest", createdAt: .distantPast, relativeAuthPath: "auth/zero-longest.json")

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
            accounts: [zeroLongest],
            outcomes: [
                Self.makeOutcome(
                    account: zeroLongest,
                    label: "Zero Longest",
                    remaining: nil,
                    primaryWindow: .init(usedPercent: 100, windowMinutes: 1440)
                )
            ],
            summaries: [
                zeroLongest.id: CodexAuthSummary(cardKind: .officialAPIKey)
            ],
            grouping: .none,
            sorting: .name,
            hideZeroQuotaAccounts: false
        )

        XCTAssertEqual(sections[0].items.map(\.displayName), ["Zero Longest"])
    }

    func testBDD_GivenHideErroredEnabled_WhenOutcomeIsFailure_ThenErroredAccountIsFilteredOut() {
        let healthy = CodexAuthAccount(id: UUID(), name: "Healthy", createdAt: .distantPast, relativeAuthPath: "auth/healthy.json")
        let failed = CodexAuthAccount(id: UUID(), name: "Failed", createdAt: .distantPast, relativeAuthPath: "auth/failed.json")

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
            accounts: [healthy, failed],
            outcomes: [
                Self.makeOutcome(account: healthy, label: "Healthy", remaining: 70),
                Self.makeFailureOutcome(account: failed, label: "Failed")
            ],
            summaries: [
                healthy.id: CodexAuthSummary(cardKind: .officialAPIKey),
                failed.id: CodexAuthSummary(cardKind: .officialAPIKey)
            ],
            grouping: .none,
            sorting: .name,
            hideZeroQuotaAccounts: false,
            hideErroredAccounts: true
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].items.map(\.displayName), ["Healthy"])
    }

    func testBDD_GivenHideErroredDisabled_WhenOutcomeIsFailure_ThenErroredAccountRemainsVisible() {
        let failed = CodexAuthAccount(id: UUID(), name: "Failed", createdAt: .distantPast, relativeAuthPath: "auth/failed.json")

        let sections = ProviderUsageEngine.makeCodexAccountDisplaySections(
            accounts: [failed],
            outcomes: [Self.makeFailureOutcome(account: failed, label: "Failed")],
            summaries: [failed.id: CodexAuthSummary(cardKind: .officialAPIKey)],
            grouping: .none,
            sorting: .name,
            hideZeroQuotaAccounts: false,
            hideErroredAccounts: false
        )

        XCTAssertEqual(sections[0].items.map(\.displayName), ["Failed"])
    }

    func testBDD_GivenSelectingCurrentSortOption_WhenTappedAgain_ThenTogglesDirection() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())

        XCTAssertEqual(viewModel.codexAccountSortOption, .remainingCredits)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .descending)

        viewModel.selectCodexSortOption(.remainingCredits)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .ascending)

        viewModel.selectCodexSortOption(.remainingCredits)
        XCTAssertEqual(viewModel.codexCurrentSortDirection, .descending)
    }

    func testBDD_GivenSelectingDifferentSortOption_WhenTapped_ThenUsesThatOptionDefaultDirection() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())

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
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())

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
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
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
        let actions = ProviderUsageEngine.codexPrimaryHeaderActions(for: .relayProfile)

        XCTAssertEqual(actions, [.refreshAll, .login, .importAuth, .editConfig, .validateConfig])
    }

    func testBDD_GivenSectionID_WhenTogglingCollapse_ThenMembershipFlips() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())

        XCTAssertFalse(viewModel.isCodexSectionCollapsed("OpenAI"))
        viewModel.toggleCodexSection("OpenAI")
        XCTAssertTrue(viewModel.isCodexSectionCollapsed("OpenAI"))
        viewModel.toggleCodexSection("OpenAI")
        XCTAssertFalse(viewModel.isCodexSectionCollapsed("OpenAI"))
    }

    func testBDD_GivenGatewayCardsSection_WhenTogglingCollapse_ThenExpandedStateFlips() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())

        XCTAssertFalse(viewModel.isGatewayCardsSectionCollapsed)
        viewModel.toggleGatewayCardsSectionCollapsed()
        XCTAssertTrue(viewModel.isGatewayCardsSectionCollapsed)
        viewModel.toggleGatewayCardsSectionCollapsed()
        XCTAssertFalse(viewModel.isGatewayCardsSectionCollapsed)
    }

    func testBDD_GivenCodexMultiSelectionMode_WhenToggledOff_ThenSelectionsAreCleared() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
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
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
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

    func testBDD_GivenCodexSectionInMultiSelection_WhenTogglingSelectAll_ThenSelectsAllAccountsInSection() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let first = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let second = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        let third = CodexAuthAccount(id: UUID(), name: "C", createdAt: .distantPast, relativeAuthPath: "auth/c.json")
        viewModel.codexAccounts = [first, second, third]
        viewModel.codexAccountOutcomes = [
            Self.makeOutcome(account: first, label: "A", remaining: 80),
            Self.makeOutcome(account: second, label: "B", remaining: 70),
            Self.makeOutcome(account: third, label: "C", remaining: 60),
        ]
        viewModel.codexAccountGroupingOption = .none
        viewModel.setCodexMultiSelectionEnabled(true)

        let section = try! XCTUnwrap(viewModel.codexAccountDisplaySections.first)
        XCTAssertFalse(viewModel.isCodexSectionFullySelected(section))

        viewModel.toggleCodexSectionSelection(section)

        XCTAssertEqual(viewModel.selectedCodexAccountIDs, Set([first.id, second.id, third.id]))
        XCTAssertTrue(viewModel.isCodexSectionFullySelected(section))
    }

    func testBDD_GivenCodexSectionAlreadyFullySelected_WhenTogglingSelectAll_ThenClearsSectionSelection() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let first = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let second = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        viewModel.codexAccounts = [first, second]
        viewModel.codexAccountOutcomes = [
            Self.makeOutcome(account: first, label: "A", remaining: 80),
            Self.makeOutcome(account: second, label: "B", remaining: 70),
        ]
        viewModel.setCodexMultiSelectionEnabled(true)

        let section = ProviderUsageEngine.CodexAccountDisplaySection(
            id: "all",
            title: "All",
            items: viewModel.codexAccountOutcomes
        )
        viewModel.selectedCodexAccountIDs = Set([first.id, second.id])
        XCTAssertTrue(viewModel.isCodexSectionFullySelected(section))

        viewModel.toggleCodexSectionSelection(section)

        XCTAssertTrue(viewModel.selectedCodexAccountIDs.isEmpty)
        XCTAssertFalse(viewModel.isCodexSectionFullySelected(section))
    }

    func testBDD_GivenMultipleSections_WhenSelectingOneSection_ThenOtherSectionSelectionRemainsUnchanged() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let first = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let second = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        let third = CodexAuthAccount(id: UUID(), name: "C", createdAt: .distantPast, relativeAuthPath: "auth/c.json")
        let firstOutcome = Self.makeOutcome(account: first, label: "A", remaining: 80)
        let secondOutcome = Self.makeOutcome(account: second, label: "B", remaining: 70)
        viewModel.setCodexMultiSelectionEnabled(true)
        viewModel.selectedCodexAccountIDs = [third.id]

        let firstSection = ProviderUsageEngine.CodexAccountDisplaySection(
            id: "first",
            title: "First",
            items: [firstOutcome, secondOutcome]
        )

        viewModel.toggleCodexSectionSelection(firstSection)

        XCTAssertEqual(viewModel.selectedCodexAccountIDs, Set([first.id, second.id, third.id]))
    }

    func testBDD_GivenImportCandidates_WhenSelectingAllAndClearing_ThenSelectionCountTracksValidItems() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
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
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
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

    func testBDD_GivenGatewayCard_WhenAddingSingleAccount_ThenMemberAppearsWithoutDuplicates() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let account = CodexAuthAccount(
            id: UUID(),
            name: "A",
            createdAt: .distantPast,
            relativeAuthPath: "auth/a.json"
        )
        viewModel.codexAccounts = [account]
        let card = viewModel.createGatewayCard(name: "网关 A")

        XCTAssertNotNil(card)
        let cardID = try! XCTUnwrap(card?.id)

        viewModel.addAccountToGatewayCard(accountID: account.id, cardID: cardID)
        viewModel.addAccountToGatewayCard(accountID: account.id, cardID: cardID)

        let updated = viewModel.gatewayCards.first(where: { $0.id == cardID })
        XCTAssertEqual(updated?.memberAccountIDs, [account.id])
    }

    func testBDD_GivenGatewayCardWithMembers_WhenSelectingCard_ThenCardBecomesActiveAndNoAutoPicker() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let account = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        viewModel.codexAccounts = [account]
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "网关激活"))
        viewModel.addAccountToGatewayCard(accountID: account.id, cardID: card.id)
        viewModel.gatewayCardsState.lastUsedCardID = nil

        let shouldPromptAdd = viewModel.activateGatewayCard(cardID: card.id)

        XCTAssertFalse(shouldPromptAdd)
        XCTAssertEqual(viewModel.gatewayCardsState.lastUsedCardID, card.id)
    }

    func testBDD_GivenEmptyGatewayCard_WhenSelectingCard_ThenCardBecomesActiveAndAutoPickerIsNeeded() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "空网关激活"))
        viewModel.gatewayCardsState.lastUsedCardID = nil

        let shouldPromptAdd = viewModel.activateGatewayCard(cardID: card.id)

        XCTAssertTrue(shouldPromptAdd)
        XCTAssertEqual(viewModel.gatewayCardsState.lastUsedCardID, card.id)
    }

    func testBDD_GivenGatewayCardSelected_WhenClearingGatewaySelection_ThenNoGatewayCardIsSelected() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "网关互斥"))
        viewModel.gatewayCardsState.lastUsedCardID = card.id

        viewModel.clearActiveGatewayCardSelection()

        XCTAssertNil(viewModel.gatewayCardsState.lastUsedCardID)
        XCTAssertFalse(viewModel.hasActiveGatewayCardSelection)
    }

    func testBDD_GivenGatewayCardWithMembers_WhenStartingGatewayFromSelection_ThenInvokesGatewayStartAction() async {
        var received: (providerID: String, host: String, port: Int)?
        let viewModel = ProviderUsageEngine(
            provider: Self.makeCodexProvider(),
            codexGatewayStartAction: { providerID, host, port in
                received = (providerID, host, port)
            }
        )
        let account = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        viewModel.codexAccounts = [account]
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "网关启动"))
        viewModel.addAccountToGatewayCard(accountID: account.id, cardID: card.id)

        await viewModel.startGatewayForCardSelection(cardID: card.id)

        XCTAssertEqual(received?.providerID, "codex")
        XCTAssertEqual(received?.host, "127.0.0.1")
        XCTAssertEqual(received?.port, 8080)
    }

    func testBDD_GivenCodexXcodeGatewayCardWithMembers_WhenStartingGatewayFromSelection_ThenFallsBackToCodexProviderID() async {
        var receivedProviderID: String?
        var provider = Self.makeCodexProvider()
        provider.templateId = ProviderTemplate.codexXcode.rawValue
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexGatewayStartAction: { providerID, _, _ in
                receivedProviderID = providerID
            }
        )
        let account = CodexAuthAccount(id: UUID(), name: "Xcode", createdAt: .distantPast, relativeAuthPath: "auth/xcode.json")
        viewModel.codexAccounts = [account]
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "Xcode 网关启动"))
        viewModel.addAccountToGatewayCard(accountID: account.id, cardID: card.id)

        await viewModel.startGatewayForCardSelection(cardID: card.id)

        XCTAssertEqual(receivedProviderID, "codex")
    }

    func testBDD_GivenEmptyGatewayCard_WhenStartingGatewayFromSelection_ThenSkipsGatewayStartAction() async {
        var invokeCount = 0
        let viewModel = ProviderUsageEngine(
            provider: Self.makeCodexProvider(),
            codexGatewayStartAction: { _, _, _ in
                invokeCount += 1
            }
        )
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "空网关"))

        await viewModel.startGatewayForCardSelection(cardID: card.id)

        XCTAssertEqual(invokeCount, 0)
    }

    func testBDD_GivenGatewayCardNotSelected_WhenStartingGatewayFromSelection_ThenSelectsCardAndStartsGateway() async {
        var invokeCount = 0
        let viewModel = ProviderUsageEngine(
            provider: Self.makeCodexProvider(),
            codexGatewayStartAction: { _, _, _ in
                invokeCount += 1
            }
        )
        let account = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        viewModel.codexAccounts = [account]
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "未选中网关"))
        viewModel.addAccountToGatewayCard(accountID: account.id, cardID: card.id)
        viewModel.gatewayCardsState.lastUsedCardID = nil

        await viewModel.startGatewayForCardSelection(cardID: card.id)

        XCTAssertEqual(invokeCount, 1)
        XCTAssertEqual(viewModel.gatewayCardsState.lastUsedCardID, card.id)
    }

    func testBDD_GivenGatewayAlreadyRunning_WhenStartingSelectedGatewayCard_ThenStopsAndRestartsGateway() async {
        var startInvocations = 0
        var stopInvocations = 0
        let viewModel = ProviderUsageEngine(
            provider: Self.makeCodexProvider(),
            codexGatewayStartAction: { _, _, _ in
                startInvocations += 1
                if startInvocations == 1 {
                    throw NolonCoreCLIError.domainFailed(
                        code: "codex_gateway_already_running",
                        message: "already running"
                    )
                }
            },
            codexGatewayStopAction: { _ in
                stopInvocations += 1
            }
        )
        let account = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        viewModel.codexAccounts = [account]
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "重启网关"))
        viewModel.addAccountToGatewayCard(accountID: account.id, cardID: card.id)

        await viewModel.startGatewayForCardSelection(cardID: card.id)

        XCTAssertEqual(startInvocations, 2)
        XCTAssertEqual(stopInvocations, 1)
        XCTAssertNil(viewModel.alertMessage)
    }

    func testBDD_GivenGatewayCardSelected_WhenConfirmingAccountActivation_ThenGatewaySelectionIsCleared() async {
        let account = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        var stoppedProviderID: String?
        let viewModel = ProviderUsageEngine(
            provider: Self.makeCodexProvider(),
            codexActivateAction: { _, _ in
                CodexAuthActivationResult(runtimeSwitched: false, runtimeErrorDescription: nil)
            },
            postActivationLoadAction: {},
            codexGatewayStopAction: { providerID in
                stoppedProviderID = providerID
            }
        )
        viewModel.codexAccounts = [account]
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "网关互斥激活"))
        viewModel.gatewayCardsState.lastUsedCardID = card.id
        viewModel.requestActivateCodexAccount(id: account.id)

        await viewModel.confirmActivate()

        XCTAssertNil(viewModel.gatewayCardsState.lastUsedCardID)
        XCTAssertFalse(viewModel.hasActiveGatewayCardSelection)
        XCTAssertEqual(stoppedProviderID, "codex")
    }

    func testBDD_GivenGatewayCardSelected_WhenActivatingAccountImmediately_ThenSkipsConfirmAndClearsGatewaySelection() async {
        let account = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        var stoppedProviderID: String?
        var activationCount = 0
        let viewModel = ProviderUsageEngine(
            provider: Self.makeCodexProvider(),
            codexActivateAction: { _, _ in
                activationCount += 1
                return CodexAuthActivationResult(runtimeSwitched: false, runtimeErrorDescription: nil)
            },
            postActivationLoadAction: {},
            codexGatewayStopAction: { providerID in
                stoppedProviderID = providerID
            }
        )
        viewModel.codexAccounts = [account]
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "右键直切"))
        viewModel.gatewayCardsState.lastUsedCardID = card.id

        await viewModel.activateCodexAccountImmediately(id: account.id)

        XCTAssertEqual(activationCount, 1)
        XCTAssertNil(viewModel.pendingActivateCodexAccount)
        XCTAssertFalse(viewModel.isShowingActivateConfirm)
        XCTAssertNil(viewModel.gatewayCardsState.lastUsedCardID)
        XCTAssertFalse(viewModel.hasActiveGatewayCardSelection)
        XCTAssertEqual(stoppedProviderID, "codex")
    }

    func testBDD_GivenActiveCodexAccountAndNoGatewaySelection_WhenTappingCard_ThenActivationIsSkipped() {
        let account = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id

        let shouldActivate = viewModel.shouldActivateCodexAccountOnTap(
            id: account.id,
            hasActiveGatewayCardSelection: false
        )

        XCTAssertFalse(shouldActivate)
    }

    func testBDD_GivenActiveCodexAccountAndGatewaySelection_WhenTappingCard_ThenActivationIsForcedForGatewayStop() {
        let account = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "网关"))
        viewModel.gatewayCardsState.lastUsedCardID = card.id

        let shouldActivate = viewModel.shouldActivateCodexAccountOnTap(
            id: account.id,
            hasActiveGatewayCardSelection: true
        )

        XCTAssertTrue(shouldActivate)
    }

    func testBDD_GivenMultiSelectedAccounts_WhenConfirmingTargetGatewayCard_ThenAllSelectedAreAdded() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let first = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let second = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        viewModel.codexAccounts = [first, second]
        let card = viewModel.createGatewayCard(name: "网关 B")
        let cardID = try! XCTUnwrap(card?.id)

        viewModel.setCodexMultiSelectionEnabled(true)
        viewModel.selectedCodexAccountIDs = [first.id, second.id]
        viewModel.addSelectedToGatewayCard()

        XCTAssertTrue(viewModel.isShowingGatewayCardPicker)
        XCTAssertEqual(Set(viewModel.pendingGatewaySelectionAccountIDs), Set([first.id, second.id]))

        viewModel.confirmAddPendingAccounts(to: cardID)

        let updated = viewModel.gatewayCards.first(where: { $0.id == cardID })
        XCTAssertEqual(Set(updated?.memberAccountIDs ?? []), Set([first.id, second.id]))
        XCTAssertFalse(viewModel.isShowingGatewayCardPicker)
    }

    func testBDD_GivenMultiSelectedAccountsOutOfOrder_WhenOpeningGatewayPicker_ThenPendingIDsFollowAccountOrder() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let first = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let second = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        let third = CodexAuthAccount(id: UUID(), name: "C", createdAt: .distantPast, relativeAuthPath: "auth/c.json")
        viewModel.codexAccounts = [first, second, third]
        _ = viewModel.createGatewayCard(name: "网关顺序")

        viewModel.setCodexMultiSelectionEnabled(true)
        viewModel.selectedCodexAccountIDs = [third.id, first.id]

        viewModel.addSelectedToGatewayCard()

        XCTAssertEqual(viewModel.pendingGatewaySelectionAccountIDs, [first.id, third.id])
    }

    func testBDD_GivenGatewayCardMembers_WhenRemovingAccount_ThenRemovedAccountDisappears() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let first = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let second = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        viewModel.codexAccounts = [first, second]
        let card = viewModel.createGatewayCard(name: "网关 C")
        let cardID = try! XCTUnwrap(card?.id)
        viewModel.addAccountsToGatewayCard(accountIDs: [first.id, second.id], cardID: cardID)

        viewModel.removeAccountFromGatewayCard(accountID: second.id, cardID: cardID)

        let updated = viewModel.gatewayCards.first(where: { $0.id == cardID })
        XCTAssertEqual(updated?.memberAccountIDs, [first.id])
    }

    func testBDD_GivenAccountListChanged_WhenAnyGatewayMutationOccurs_ThenInvalidMembersAreCleaned() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let valid = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let removed = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        viewModel.codexAccounts = [valid, removed]
        let card = viewModel.createGatewayCard(name: "网关 D")
        let cardID = try! XCTUnwrap(card?.id)
        viewModel.addAccountsToGatewayCard(accountIDs: [valid.id, removed.id], cardID: cardID)

        viewModel.codexAccounts = [valid]
        viewModel.addAccountsToGatewayCard(accountIDs: [valid.id], cardID: cardID)

        let updated = viewModel.gatewayCards.first(where: { $0.id == cardID })
        XCTAssertEqual(updated?.memberAccountIDs, [valid.id])
    }

    func testBDD_GivenMultipleGatewayCards_WhenDeletingOne_ThenOtherCardsRemainUnchanged() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let account = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        viewModel.codexAccounts = [account]

        let first = viewModel.createGatewayCard(name: "网关 1")
        let second = viewModel.createGatewayCard(name: "网关 2")
        let firstID = try! XCTUnwrap(first?.id)
        let secondID = try! XCTUnwrap(second?.id)
        viewModel.addAccountToGatewayCard(accountID: account.id, cardID: firstID)
        viewModel.addAccountToGatewayCard(accountID: account.id, cardID: secondID)

        viewModel.deleteGatewayCard(cardID: firstID)

        XCTAssertNil(viewModel.gatewayCards.first(where: { $0.id == firstID }))
        let remaining = viewModel.gatewayCards.first(where: { $0.id == secondID })
        XCTAssertEqual(remaining?.memberAccountIDs, [account.id])
    }

    func testBDD_GivenGatewayCardWithExistingMembers_WhenQueryingCandidateAccounts_ThenExcludesExistingMembers() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let first = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let second = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        let third = CodexAuthAccount(id: UUID(), name: "C", createdAt: .distantPast, relativeAuthPath: "auth/c.json")
        viewModel.codexAccounts = [first, second, third]
        let card = viewModel.createGatewayCard(name: "网关 E")
        let cardID = try! XCTUnwrap(card?.id)
        viewModel.addAccountsToGatewayCard(accountIDs: [second.id], cardID: cardID)

        let candidates = viewModel.gatewayCandidateAccounts(for: cardID)

        XCTAssertEqual(candidates.map(\.id), [first.id, third.id])
    }

    func testBDD_GivenUnknownGatewayCardID_WhenQueryingCandidateAccounts_ThenReturnsAllAccounts() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let first = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let second = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        viewModel.codexAccounts = [first, second]

        let candidates = viewModel.gatewayCandidateAccounts(for: UUID())

        XCTAssertEqual(candidates.map(\.id), [first.id, second.id])
    }

    func testBDD_GivenGatewayCandidates_WhenBuildingCandidateSections_ThenContainsGroupingInfoAndKeepsOrderInEachGroup() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let plus = CodexAuthAccount(id: UUID(), name: "Plus", createdAt: .distantPast, relativeAuthPath: "auth/plus.json")
        let relayA = CodexAuthAccount(id: UUID(), name: "Relay A", createdAt: .distantPast, relativeAuthPath: "auth/relay-a.json")
        let openAI = CodexAuthAccount(id: UUID(), name: "OpenAI", createdAt: .distantPast, relativeAuthPath: "auth/openai.json")
        let relayB = CodexAuthAccount(id: UUID(), name: "Relay B", createdAt: .distantPast, relativeAuthPath: "auth/relay-b.json")
        viewModel.codexAccounts = [plus, relayA, openAI, relayB]
        viewModel.codexAccountSummaries = [
            plus.id: CodexAuthSummary(plan: "Plus", cardKind: .chatgptAccount),
            relayA.id: CodexAuthSummary(cardKind: .relayProfile, relayModelProvider: "relay"),
            openAI.id: CodexAuthSummary(cardKind: .officialAPIKey),
            relayB.id: CodexAuthSummary(cardKind: .relayProfile, relayModelProvider: "RELAY")
        ]

        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "网关分组"))
        let sections = viewModel.gatewayCandidateSections(for: card.id)

        XCTAssertEqual(Set(sections.map(\.title)), Set(["Plus", "Relay", "OpenAI"]))
        XCTAssertEqual(
            sections.first(where: { $0.title == "Relay" })?.items.map(\.id),
            [relayA.id, relayB.id]
        )
    }

    func testBDD_GivenGatewayCardHasMembers_WhenBuildingCandidateSections_ThenExistingMembersAreExcluded() {
        let viewModel = ProviderUsageEngine(provider: Self.makeCodexProvider())
        let first = CodexAuthAccount(id: UUID(), name: "A", createdAt: .distantPast, relativeAuthPath: "auth/a.json")
        let second = CodexAuthAccount(id: UUID(), name: "B", createdAt: .distantPast, relativeAuthPath: "auth/b.json")
        viewModel.codexAccounts = [first, second]
        viewModel.codexAccountSummaries = [
            first.id: CodexAuthSummary(cardKind: .officialAPIKey),
            second.id: CodexAuthSummary(plan: "Plus", cardKind: .chatgptAccount)
        ]
        let card = try! XCTUnwrap(viewModel.createGatewayCard(name: "网关过滤"))
        viewModel.addAccountToGatewayCard(accountID: first.id, cardID: card.id)

        let sections = viewModel.gatewayCandidateSections(for: card.id)

        XCTAssertEqual(sections.flatMap(\.items).map(\.id), [second.id])
    }

    func testBDD_GivenGatewayVirtualAuthPayload_WhenCheckingVirtualAccount_ThenReturnsTrue() throws {
        let raw = """
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "nolon-gateway-virtual-api-key",
          "nolon": {
            "relay": {
              "base_url": "http://127.0.0.1:8080",
              "model_provider": "openai",
              "query_params": {
                "nolon_gateway_virtual": "1",
                "provider_id": "codex"
              }
            }
          }
        }
        """
        let data = try XCTUnwrap(raw.data(using: .utf8))

        let isVirtual = ProviderUsageEngine.isGatewayVirtualCodexAccount(
            relativeAuthPath: "auth/openai.json",
            authData: data
        )

        XCTAssertTrue(isVirtual)
    }

    func testBDD_GivenNormalRelayAuthPayload_WhenCheckingVirtualAccount_ThenReturnsFalse() throws {
        let raw = """
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "normal-key",
          "nolon": {
            "relay": {
              "base_url": "https://relay.example.com",
              "model_provider": "openai",
              "query_params": {
                "provider_id": "codex"
              }
            }
          }
        }
        """
        let data = try XCTUnwrap(raw.data(using: .utf8))

        let isVirtual = ProviderUsageEngine.isGatewayVirtualCodexAccount(
            relativeAuthPath: "auth/my-relay.json",
            authData: data
        )

        XCTAssertFalse(isVirtual)
    }

    func testBDD_GivenVirtualAPIKeyWithoutMarker_WhenCheckingVirtualAccount_ThenReturnsTrue() throws {
        let raw = """
        {
          "auth_mode": "apikey",
          "OPENAI_API_KEY": "nolon-gateway-virtual-api-key",
          "tokens": null
        }
        """
        let data = try XCTUnwrap(raw.data(using: .utf8))

        let isVirtual = ProviderUsageEngine.isGatewayVirtualCodexAccount(
            relativeAuthPath: "auth/polluted-virtual.json",
            authData: data
        )

        XCTAssertTrue(isVirtual)
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

    private static func makeFailureOutcome(
        account: CodexAuthAccount,
        label: String
    ) -> ProviderAccountUsageOutcome {
        let tokenAccount = ProviderTokenAccount(
            id: account.id,
            label: label,
            token: "",
            addedAt: account.createdAt.timeIntervalSince1970,
            lastUsed: nil
        )

        return ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(tokenAccount),
            outcome: .init(fetchKind: .cli, result: .failure(ProviderUsageError.authExpired(.codex)))
        )
    }
}
