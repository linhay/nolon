import AppKit
import Foundation
import SnapshotTesting
import SwiftUI
import Testing
import NolonUI
@testable import nolon

@MainActor
@Suite("ToastView Snapshot")
struct ToastViewSnapshotTests {
    private static let snapshotSize = CGSize(width: 360, height: 120)
    private static let snapshotDirectory: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent("ToastViewSnapshotTests", isDirectory: true)
            .path
    }()

    @Test("neutral style screenshot")
    func neutralStyleScreenshot() {
        let host = makeToastHost(style: .neutral, systemImage: "tray.full.fill")
        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.snapshotSize),
                named: "neutral",
                snapshotDirectory: Self.snapshotDirectory
            )
        }
        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    @Test("success style screenshot")
    func successStyleScreenshot() {
        let host = makeToastHost(style: .success, systemImage: "checkmark.circle.fill")
        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.snapshotSize),
                named: "success",
                snapshotDirectory: Self.snapshotDirectory
            )
        }
        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    private func makeToastHost(
        style: ToastView.Style,
        systemImage: String?
    ) -> NSHostingController<AnyView> {
        let rootView = AnyView(
            ToastView(
            text: "Synced 8 resources",
            systemImage: systemImage,
            style: style
        )
        .padding(24)
        .frame(
            width: Self.snapshotSize.width,
            height: Self.snapshotSize.height,
            alignment: .leading
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
