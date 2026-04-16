import XCTest
import NolonUIFoundation
@testable import nolon

final class CodexSessionsOverviewDataBuilderTests: XCTestCase {
    func testBDD_GivenProjectIdleContext_WhenBuildingOverview_ThenUsesCompactModeAndCompactMetrics() {
        let data = CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: .project,
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                needsAttentionGroupCount: 1,
                statusMessage: nil,
                isLoading: false,
                hasVisibleSections: true,
                isPreparingRewrite: false,
                isApplyingRewrite: false
            )
        )

        XCTAssertEqual(data.displayMode, .compact)
        XCTAssertEqual(data.selectedGroupingID, "project")
        XCTAssertEqual(data.subtitle, "Browse sessions by project.")
        XCTAssertEqual(data.metrics.map(\.id), ["sessions", "groups", "attention"])
        XCTAssertFalse(data.isRefreshDisabled)
        XCTAssertNil(data.backgroundScanningMessage)
    }

    func testBDD_GivenProviderIdleContext_WhenBuildingOverview_ThenUsesCompactModeWithProviderCopy() {
        let data = CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: .provider,
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                needsAttentionGroupCount: 1,
                statusMessage: nil,
                isLoading: false,
                hasVisibleSections: true,
                isPreparingRewrite: false,
                isApplyingRewrite: false
            )
        )

        XCTAssertEqual(data.displayMode, .compact)
        XCTAssertEqual(data.selectedGroupingID, "provider")
        XCTAssertEqual(data.subtitle, "Audit sessions by provider.")
        XCTAssertEqual(data.metrics.map(\.id), ["sessions", "groups", "attention"])
        XCTAssertFalse(data.isRefreshDisabled)
    }

    func testBDD_GivenBackgroundScanWithVisibleSections_WhenBuildingOverview_ThenSwitchesToDiagnosticMode() {
        let data = CodexSessionsOverviewDataBuilder.build(
            .init(
                groupingMode: .project,
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                needsAttentionGroupCount: 1,
                statusMessage: nil,
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
        XCTAssertEqual(data.metrics.map(\.id), ["sessions", "groups", "rewritable", "attention"])
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
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                needsAttentionGroupCount: 1,
                statusMessage: "Preparing rewrite preview…",
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
                totalSessionCount: 18,
                groupCount: 4,
                rewritableGroupCount: 3,
                needsAttentionGroupCount: 1,
                statusMessage: "Moved 3 sessions to Anthropic (anthropic).",
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
        XCTAssertEqual(data.metrics.map(\.id), ["sessions", "groups", "rewritable", "attention"])
    }
}
