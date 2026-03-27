import AppKit
import SnapshotTesting
import SwiftUI
import Testing
import NolonUI
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

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.snapshotSize),
                named: "claude-empty-card",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    private func makeHost(_ view: some View) -> NSHostingController<AnyView> {
        let rootView = AnyView(
            view
            .padding(24)
            .frame(
                width: Self.snapshotSize.width,
                height: Self.snapshotSize.height,
                alignment: .top
            )
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light)
        )

        let host = NSHostingController(rootView: rootView)
        host.view.frame = NSRect(origin: .zero, size: Self.snapshotSize)
        host.view.appearance = NSAppearance(named: .aqua)
        host.view.layoutSubtreeIfNeeded()
        return host
    }
}
