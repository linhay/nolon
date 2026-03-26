import AppKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import nolon

@MainActor
@Suite("Provider Usage Empty State Card Snapshot")
struct ProviderUsageEmptyStateCardSnapshotTests {
    private static let snapshotSize = CGSize(width: 900, height: 320)
    private static let snapshotDirectory: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent("ProviderUsageEmptyStateCardSnapshotTests", isDirectory: true)
            .path
    }()

    @Test("claude empty card screenshot")
    func claudeEmptyCardScreenshot() {
        let host = makeHost(
            ProviderUsageEmptyStateCard(
                title: "No Claude accounts",
                systemImage: "person.crop.circle.badge.exclamationmark",
                descriptionText: Text("Use \"迁移\" or \"从 cc-switch 导入\" to add accounts.")
            )
        )

        let failure = withSnapshotTesting(record: .failed) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.snapshotSize),
                named: "claude-empty-card",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil)
    }

    private func makeHost(_ view: some View) -> NSHostingController<some View> {
        let rootView =
            view
            .padding(24)
            .frame(
                width: Self.snapshotSize.width,
                height: Self.snapshotSize.height,
                alignment: .top
            )
            .background(DesignSystem.Colors.Background.canvas)
            .environment(\.colorScheme, .light)

        let host = NSHostingController(rootView: rootView)
        host.view.frame = NSRect(origin: .zero, size: Self.snapshotSize)
        host.view.appearance = NSAppearance(named: .aqua)
        host.view.layoutSubtreeIfNeeded()
        return host
    }
}
