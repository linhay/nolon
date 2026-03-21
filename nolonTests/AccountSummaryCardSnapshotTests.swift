import AppKit
import SnapshotTesting
import SwiftUI
import Testing
import NolonUIFoundation
@testable import nolon

@MainActor
@Suite("Account Summary Card Snapshot")
struct AccountSummaryCardSnapshotTests {
    private static let snapshotSize = CGSize(width: 420, height: 220)
    private static let snapshotDirectory: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent("AccountSummaryCardSnapshotTests", isDirectory: true)
            .path
    }()

    @Test("long title keeps readable width when trailing meta exists")
    func longTitleKeepsReadableWidthWhenTrailingMetaExists() {
        let header = AccountSummaryCardHeaderModel(
            eyebrow: "Codex",
            title: "dzurillaisadore@gmail.com extremely long account alias for regression",
            subtitle: "Pro plan",
            meta: "Updated 2026-03-16 22:59",
            badge: AccountSummaryCardBadgeModel(text: "ACTIVE", tone: .active)
        )

        let card = AccountSummaryContentCard(
            presentation: .active,
            header: header,
            showsDetailsSection: false,
            showsActionsSection: false
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Usage")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Rectangle()
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .frame(height: 32)
            }
        }

        let host = makeHost(card)

        let failure = withSnapshotTesting(record: .failed) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.snapshotSize),
                named: "long-title-trailing-meta",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil)
    }

    @Test("card content keeps grouped rhythm with details and actions")
    func cardContentKeepsGroupedRhythmWithDetailsAndActions() {
        let header = AccountSummaryCardHeaderModel(
            eyebrow: "Codex",
            title: "dzurillaisadore@gmail.com",
            subtitle: "Pro plan",
            meta: "Updated 2026-03-16 22:59",
            badge: AccountSummaryCardBadgeModel(text: "ACTIVE", tone: .active)
        )

        let card = AccountSummaryContentCard(
            presentation: .active,
            header: header,
            showsDetailsSection: true,
            showsActionsSection: true
        ) {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .fill(DesignSystem.Colors.Component.controlFill)
                .frame(height: 52)
        } details: {
            VStack(alignment: .leading, spacing: 10) {
                cardRow(title: "Source", value: "auth.json", auxiliary: nil)
                cardRow(title: "Runtime Home", value: "~/.codex", auxiliary: "local")
            }
        } actions: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    actionChip("Refresh")
                    actionChip("Set Active")
                }
                footerRow
            }
        }

        let host = makeHost(card)

        let failure = withSnapshotTesting(record: .failed) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.snapshotSize),
                named: "grouped-card-content",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil)
    }

    @Test("error body state stays readable with retry actions")
    func errorBodyStateStaysReadableWithRetryActions() {
        let header = AccountSummaryCardHeaderModel(
            eyebrow: "Gemini",
            title: "staging-account@flowup.dev",
            subtitle: "Starter plan",
            meta: "Failed 2m ago",
            badge: AccountSummaryCardBadgeModel(text: "WARNING", tone: .warning)
        )

        let card = AccountSummaryContentCard(
            presentation: .neutral,
            header: header,
            showsDetailsSection: false,
            showsActionsSection: true
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sync Failed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Status.error)
                Text("Rate service timeout. Retry after a short delay.")
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.Status.error.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
        } actions: {
            HStack(spacing: 8) {
                actionChip("Retry")
                actionChip("Details")
            }
        }

        let host = makeHost(card)

        let failure = withSnapshotTesting(record: .failed) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.snapshotSize),
                named: "error-body-state",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil)
    }

    @Test("loading skeleton state keeps rhythm in compact body")
    func loadingSkeletonStateKeepsRhythmInCompactBody() {
        let header = AccountSummaryCardHeaderModel(
            eyebrow: "OpenAI",
            title: "loading-account@flowup.dev",
            subtitle: "Syncing usage…",
            meta: "Just now",
            badge: AccountSummaryCardBadgeModel(text: "SYNCING", tone: .neutral)
        )

        let card = AccountSummaryContentCard(
            presentation: .neutral,
            header: header,
            showsDetailsSection: false,
            showsActionsSection: false
        ) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .frame(height: 12)
                    .frame(maxWidth: 210)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .frame(height: 12)
                    .frame(maxWidth: 160)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .frame(height: 12)
                    .frame(maxWidth: 240)
            }
            .redacted(reason: .placeholder)
        }

        let host = makeHost(card)

        let failure = withSnapshotTesting(record: .failed) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.snapshotSize),
                named: "loading-skeleton-state",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil)
    }

    private func cardRow(title: String, value: String, auxiliary: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            if let auxiliary {
                Text(auxiliary)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionChip(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignSystem.Colors.Text.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
            )
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            Text("SYNCED")
                .font(.system(size: 8, weight: .black))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(DesignSystem.Colors.primary.opacity(0.15))
                )
                .foregroundStyle(DesignSystem.Colors.primary)

            Spacer(minLength: 0)

            Text("moments ago")
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        }
    }

    private func makeHost(_ view: some View) -> NSHostingController<AnyView> {
        let rootView = AnyView(
            view
                .padding(20)
                .frame(
                    width: Self.snapshotSize.width,
                    height: Self.snapshotSize.height,
                    alignment: .topLeading
                )
                .background(DesignSystem.Colors.Background.canvas)
                .environment(\.colorScheme, .light)
        )

        let host = NSHostingController(rootView: rootView)
        host.view.frame = NSRect(origin: .zero, size: Self.snapshotSize)
        host.view.appearance = NSAppearance(named: .aqua)
        host.view.layoutSubtreeIfNeeded()
        return host
    }
}
