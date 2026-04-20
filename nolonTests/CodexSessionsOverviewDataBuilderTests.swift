import XCTest
import NolonUIFoundation
@testable import nolon

final class CodexSessionsOverviewDataBuilderTests: XCTestCase {
    func testBDD_GivenProjectIdleContext_WhenBuildingOverview_ThenUsesCompactModeAndCompactMetrics() {
        let data = CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: .project,
                sortMode: .recent,
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                totalUsage: .value(primaryText: "18.6K", secondaryText: nil),
                groupUsage: .value(primaryText: "18.6K", secondaryText: nil),
                rewritableGroupUsage: .value(primaryText: "15.0K", secondaryText: nil),
                statusMessage: nil,
                diagnosticMessage: nil,
                isLoading: false,
                hasVisibleSections: true,
                isPreparingRewrite: false,
                isApplyingRewrite: false
            )
        )

        XCTAssertEqual(data.displayMode, .compact)
        XCTAssertEqual(data.selectedGroupingID, "project")
        XCTAssertEqual(data.subtitle, "Browse sessions by project.")
        XCTAssertEqual(data.metrics.map(\.id), ["sessions", "groups"])
        XCTAssertEqual(data.metrics.map(\.detailText), [usageDetail("18.6K"), usageDetail("18.6K")])
        XCTAssertFalse(data.isRefreshDisabled)
        XCTAssertNil(data.backgroundScanningMessage)
    }

    func testBDD_GivenProviderIdleContext_WhenBuildingOverview_ThenUsesCompactModeWithProviderCopy() {
        let data = CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: .provider,
                sortMode: .recent,
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                totalUsage: .value(primaryText: "18.6K", secondaryText: nil),
                groupUsage: .value(primaryText: "18.6K", secondaryText: nil),
                rewritableGroupUsage: .value(primaryText: "15.0K", secondaryText: nil),
                statusMessage: nil,
                diagnosticMessage: nil,
                isLoading: false,
                hasVisibleSections: true,
                isPreparingRewrite: false,
                isApplyingRewrite: false
            )
        )

        XCTAssertEqual(data.displayMode, .compact)
        XCTAssertEqual(data.selectedGroupingID, "provider")
        XCTAssertEqual(data.subtitle, "Audit sessions by provider.")
        XCTAssertEqual(data.metrics.map(\.id), ["sessions", "groups"])
        XCTAssertEqual(data.metrics.map(\.detailText), [usageDetail("18.6K"), usageDetail("18.6K")])
        XCTAssertFalse(data.isRefreshDisabled)
    }

    func testBDD_GivenBackgroundScanWithVisibleSections_WhenBuildingOverview_ThenSwitchesToDiagnosticMode() {
        let data = CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: .project,
                sortMode: .recent,
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                totalUsage: .value(primaryText: "18.6K", secondaryText: nil),
                groupUsage: .value(primaryText: "18.6K", secondaryText: nil),
                rewritableGroupUsage: .value(primaryText: "15.0K", secondaryText: nil),
                statusMessage: nil,
                diagnosticMessage: nil,
                isLoading: true,
                hasVisibleSections: true,
                isPreparingRewrite: false,
                isApplyingRewrite: false
            )
        )

        XCTAssertEqual(data.displayMode, .diagnostic)
        XCTAssertEqual(
            data.subtitle,
            "Browse sessions by project first. Rewrite and diagnostics stay available from group and row menus."
        )
        XCTAssertEqual(data.metrics.map(\.id), ["sessions", "groups", "rewritable"])
        XCTAssertEqual(
            data.metrics.map(\.detailText),
            [usageDetail("18.6K"), usageDetail("18.6K"), usageDetail("15.0K")]
        )
        XCTAssertEqual(
            data.backgroundScanningMessage,
            NSLocalizedString(
                "codex.sessions.status.scanning",
                value: "Scanning sessions in background…",
                comment: "Codex sessions background scanning status"
            )
        )
        XCTAssertTrue(data.isRefreshDisabled)
    }

    func testBDD_GivenPreparingRewrite_WhenBuildingOverview_ThenUsesDiagnosticModeAndDisablesRefresh() {
        let data = CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: .project,
                sortMode: .recent,
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                totalUsage: .value(primaryText: "18.6K", secondaryText: nil),
                groupUsage: .value(primaryText: "18.6K", secondaryText: nil),
                rewritableGroupUsage: .value(primaryText: "15.0K", secondaryText: nil),
                statusMessage: "Preparing rewrite preview…",
                diagnosticMessage: nil,
                isLoading: false,
                hasVisibleSections: true,
                isPreparingRewrite: true,
                isApplyingRewrite: false
            )
        )

        XCTAssertEqual(data.displayMode, .diagnostic)
        XCTAssertEqual(data.statusMessage, "Preparing rewrite preview…")
        XCTAssertTrue(data.isRefreshDisabled)
        XCTAssertNil(data.backgroundScanningMessage)
    }

    func testBDD_GivenApplyingRewriteAndBackgroundScan_WhenBuildingOverview_ThenKeepsDiagnosticModeAndBothStatusMessages() {
        let data = CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: .provider,
                sortMode: .recent,
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                totalUsage: .value(primaryText: "18.6K", secondaryText: nil),
                groupUsage: .value(primaryText: "18.6K", secondaryText: nil),
                rewritableGroupUsage: .value(primaryText: "15.0K", secondaryText: nil),
                statusMessage: "Moved 3 sessions to Anthropic (anthropic).",
                diagnosticMessage: nil,
                isLoading: true,
                hasVisibleSections: true,
                isPreparingRewrite: false,
                isApplyingRewrite: true
            )
        )

        XCTAssertEqual(data.displayMode, .diagnostic)
        XCTAssertEqual(data.statusMessage, "Moved 3 sessions to Anthropic (anthropic).")
        XCTAssertEqual(
            data.backgroundScanningMessage,
            NSLocalizedString(
                "codex.sessions.status.scanning",
                value: "Scanning sessions in background…",
                comment: "Codex sessions background scanning status"
            )
        )
        XCTAssertTrue(data.isRefreshDisabled)
        XCTAssertEqual(data.metrics.map(\.id), ["sessions", "groups", "rewritable"])
        XCTAssertEqual(
            data.metrics.map(\.detailText),
            [usageDetail("18.6K"), usageDetail("18.6K"), usageDetail("15.0K")]
        )
    }

    func testBDD_GivenDiagnosticMessage_WhenBuildingOverview_ThenRoutesItToDiagnosticFooterEntry() {
        let data = CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: .project,
                sortMode: .recent,
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                totalUsage: .placeholder(text: "Loading…"),
                groupUsage: .placeholder(text: "Loading…"),
                rewritableGroupUsage: .placeholder(text: "Loading…"),
                statusMessage: nil,
                diagnosticMessage: "Config warning: falling back to default provider.",
                isLoading: false,
                hasVisibleSections: true,
                isPreparingRewrite: false,
                isApplyingRewrite: false
            )
        )

        XCTAssertNil(data.statusMessage)
        XCTAssertEqual(data.paginationMessage, "Config warning: falling back to default provider.")
        XCTAssertEqual(
            data.metrics.map(\.detailText),
            [usageDetail("Loading…"), usageDetail("Loading…")]
        )
    }

    private func usageDetail(_ value: String) -> String {
        let usageTitle = NSLocalizedString(
            "codex.usage.title",
            value: "Usage",
            comment: "Codex usage title"
        )
        return "\(usageTitle) \(value)"
    }
}
