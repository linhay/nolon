import XCTest
import Foundation
import ProviderCatalog
import ProviderUsage
@testable import nolon

@MainActor
final class CodexQuickSwitchMenuBarSupportTests: XCTestCase {
    func testBDD_GivenUsageWindows_WhenFormattingSummaryLine_ThenPrefersFiveHourAndWeeklyWindows() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 18, hour: 12, minute: 0, second: 0))!
        let shortReset = now.addingTimeInterval(3 * 3600 + 10 * 60)
        let weeklyReset = calendar.date(from: DateComponents(year: 2026, month: 3, day: 24, hour: 17, minute: 10, second: 0))!

        let usage = UsageSnapshot(
            identity: nil,
            windows: [
                UsageWindow(id: "h5", title: "5h", window: RateWindow(usedPercent: 14, resetsAt: shortReset, windowMinutes: 300)),
                UsageWindow(id: "w1", title: "weekly", window: RateWindow(usedPercent: 52, resetsAt: weeklyReset, windowMinutes: 10_080))
            ],
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: now
        )

        let line = CodexQuickSwitchUsageFormatter.summaryLine(usage: usage, now: now)

        XCTAssertEqual(line, "5h 86% (03:10) · weekly 48% (03/24 17:10)")
    }

    func testBDD_GivenRemainingQuotaAboveThreshold_WhenCheckingIsExhausted_ThenReturnsFalse() {
        let row = CodexQuickSwitchMenuBarViewModel.Row(
            id: UUID(),
            title: "Account A",
            detail: nil,
            isActive: false,
            usageWindows: [
                UsageWindow(
                    id: "primary",
                    title: "primary",
                    window: RateWindow(usedPercent: 99.8)
                )
            ]
        )

        XCTAssertFalse(row.isExhausted)
    }

    func testBDD_GivenRemainingQuotaAtOrBelowThreshold_WhenCheckingIsExhausted_ThenReturnsTrue() {
        let exhaustedRow = CodexQuickSwitchMenuBarViewModel.Row(
            id: UUID(),
            title: "Account B",
            detail: nil,
            isActive: false,
            usageWindows: [
                UsageWindow(
                    id: "primary",
                    title: "primary",
                    window: RateWindow(usedPercent: 99.9)
                )
            ]
        )

        let overExhaustedRow = CodexQuickSwitchMenuBarViewModel.Row(
            id: UUID(),
            title: "Account C",
            detail: nil,
            isActive: false,
            usageWindows: [
                UsageWindow(
                    id: "primary",
                    title: "primary",
                    window: RateWindow(usedPercent: 100)
                )
            ]
        )

        XCTAssertTrue(exhaustedRow.isExhausted)
        XCTAssertTrue(overExhaustedRow.isExhausted)
    }

    func testBDD_GivenProviderList_WhenResolvingCodexProvider_ThenFollowsProviderOrder() {
        let codexXcode = Provider(
            id: "codex-xcode-provider",
            kind: .vendor,
            name: "Codex Xcode",
            defaultSkillsPath: "~/Library/Developer/Xcode/CodingAssistant/codex/skills",
            workflowPath: "~/Library/Developer/Xcode/CodingAssistant/codex/workflows",
            iconName: "hammer",
            installMethod: .symlink,
            templateId: "codexXcode"
        )
        let codex = Provider(
            id: "codex-provider",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/workflows",
            iconName: "bolt",
            installMethod: .symlink,
            templateId: "codex"
        )

        let resolved = CodexQuickSwitchProviderResolver.resolve(from: [codexXcode, codex])

        XCTAssertEqual(resolved?.id, codexXcode.id)
    }

    func testBDD_GivenPreferredProviderID_WhenResolvingCodexProvider_ThenUsesPreferredOne() {
        let codexXcode = Provider(
            id: "codex-xcode-provider",
            kind: .vendor,
            name: "Codex Xcode",
            defaultSkillsPath: "~/Library/Developer/Xcode/CodingAssistant/codex/skills",
            workflowPath: "~/Library/Developer/Xcode/CodingAssistant/codex/workflows",
            iconName: "hammer",
            installMethod: .symlink,
            templateId: "codexXcode"
        )
        let codex = Provider(
            id: "codex-provider",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/workflows",
            iconName: "bolt",
            installMethod: .symlink,
            templateId: "codex"
        )

        let resolved = CodexQuickSwitchProviderResolver.resolve(
            from: [codexXcode, codex],
            preferredProviderID: codex.id
        )

        XCTAssertEqual(resolved?.id, codex.id)
    }

    func testBDD_GivenGeminiAndCodexProviders_WhenResolvingCandidates_ThenIncludesGemini() {
        let gemini = Provider(
            id: "gemini-provider",
            kind: .vendor,
            name: "Gemini",
            defaultSkillsPath: "~/.gemini/skills",
            workflowPath: "~/.gemini/workflows",
            iconName: "sparkles",
            installMethod: .symlink,
            templateId: "gemini"
        )
        let codex = Provider(
            id: "codex-provider",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/workflows",
            iconName: "bolt",
            installMethod: .symlink,
            templateId: "codex"
        )

        let candidates = CodexQuickSwitchProviderResolver.providers(from: [gemini, codex])

        XCTAssertEqual(candidates.map(\.id), [gemini.id, codex.id])
    }

    func testQuickSwitchSort_activeAccountAlwaysFirst_evenWhenNoQuota() {
        let entries: [CodexQuickSwitchAccountSorter.Entry] = [
            makeSortEntry(id: "B", isActive: false, remainingPercents: [80], createdAt: 20),
            makeSortEntry(id: "A", isActive: true, remainingPercents: [0, 0], createdAt: 10),
            makeSortEntry(id: "C", isActive: false, remainingPercents: [60], createdAt: 30)
        ]

        let sorted = CodexQuickSwitchAccountSorter.sort(entries).map(\.id)

        XCTAssertEqual(sorted, ["A", "B", "C"])
    }

    func testQuickSwitchSort_accountsWithQuotaBeforeZeroQuota() {
        let entries: [CodexQuickSwitchAccountSorter.Entry] = [
            makeSortEntry(id: "A", isActive: true, remainingPercents: [50], createdAt: 10),
            makeSortEntry(id: "B", isActive: false, remainingPercents: [0, 0], createdAt: 20),
            makeSortEntry(id: "C", isActive: false, remainingPercents: [10], createdAt: 30)
        ]

        let sorted = CodexQuickSwitchAccountSorter.sort(entries).map(\.id)

        XCTAssertEqual(sorted, ["A", "C", "B"])
    }

    func testQuickSwitchSort_sortByMaxRemainingPercentDescending() {
        let entries: [CodexQuickSwitchAccountSorter.Entry] = [
            makeSortEntry(id: "A", isActive: true, remainingPercents: [40], createdAt: 10),
            makeSortEntry(id: "B", isActive: false, remainingPercents: [20, 70], createdAt: 20),
            makeSortEntry(id: "C", isActive: false, remainingPercents: [65], createdAt: 30)
        ]

        let sorted = CodexQuickSwitchAccountSorter.sort(entries).map(\.id)

        XCTAssertEqual(sorted, ["A", "B", "C"])
    }

    func testQuickSwitchSort_independentPerAccountWindowSets() {
        let entries: [CodexQuickSwitchAccountSorter.Entry] = [
            makeSortEntry(id: "A", isActive: true, remainingPercents: [30], createdAt: 10),
            makeSortEntry(id: "B", isActive: false, remainingPercents: [15, 35, 5], createdAt: 20),
            makeSortEntry(id: "C", isActive: false, remainingPercents: [34], createdAt: 30)
        ]

        let sorted = CodexQuickSwitchAccountSorter.sort(entries).map(\.id)

        XCTAssertEqual(sorted, ["A", "B", "C"])
    }

    func testQuickSwitchSort_nilOrEmptyUsageTreatedAsNoQuota() {
        let entries: [CodexQuickSwitchAccountSorter.Entry] = [
            makeSortEntry(id: "A", isActive: true, remainingPercents: [], createdAt: 10),
            makeSortEntry(id: "B", isActive: false, remainingPercents: [], createdAt: 20),
            makeSortEntry(id: "C", isActive: false, remainingPercents: [5], createdAt: 30)
        ]

        let sorted = CodexQuickSwitchAccountSorter.sort(entries).map(\.id)

        XCTAssertEqual(sorted, ["A", "C", "B"])
    }

    func testQuickSwitchSort_invalidWindowValuesTreatedAsNoQuota() {
        let entries: [CodexQuickSwitchAccountSorter.Entry] = [
            makeSortEntry(id: "A", isActive: true, remainingPercents: [10], createdAt: 10),
            makeSortEntry(id: "B", isActive: false, remainingPercents: [-5, .nan, .infinity], createdAt: 20),
            makeSortEntry(id: "C", isActive: false, remainingPercents: [1], createdAt: 30)
        ]

        let sorted = CodexQuickSwitchAccountSorter.sort(entries).map(\.id)

        XCTAssertEqual(sorted, ["A", "C", "B"])
    }

    func testQuickSwitchSort_tieBreakerByCreatedAtDescending() {
        let entries: [CodexQuickSwitchAccountSorter.Entry] = [
            makeSortEntry(id: "A", isActive: true, remainingPercents: [50], createdAt: 10),
            makeSortEntry(id: "B", isActive: false, remainingPercents: [20], createdAt: 200),
            makeSortEntry(id: "C", isActive: false, remainingPercents: [20], createdAt: 100)
        ]

        let sorted = CodexQuickSwitchAccountSorter.sort(entries).map(\.id)

        XCTAssertEqual(sorted, ["A", "B", "C"])
    }

    func testQuickSwitchSort_finalTieBreakerByUUIDAscending() {
        let entries: [CodexQuickSwitchAccountSorter.Entry] = [
            makeSortEntry(id: "A", isActive: true, remainingPercents: [50], createdAt: 10),
            makeSortEntry(id: "00000000-0000-0000-0000-000000000020", isActive: false, remainingPercents: [20], createdAt: 100),
            makeSortEntry(id: "00000000-0000-0000-0000-000000000010", isActive: false, remainingPercents: [20], createdAt: 100)
        ]

        let sorted = CodexQuickSwitchAccountSorter.sort(entries).map(\.id)

        XCTAssertEqual(sorted, ["A", "00000000-0000-0000-0000-000000000010", "00000000-0000-0000-0000-000000000020"])
    }

    private func makeSortEntry(
        id: String,
        isActive: Bool,
        remainingPercents: [Double],
        createdAt secondsSince1970: TimeInterval
    ) -> CodexQuickSwitchAccountSorter.Entry {
        .init(
            id: id,
            isActive: isActive,
            remainingPercents: remainingPercents,
            createdAt: Date(timeIntervalSince1970: secondsSince1970)
        )
    }
}
