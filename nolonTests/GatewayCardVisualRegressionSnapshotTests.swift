import AppKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import nolon

@MainActor
@Suite("Gateway Card Visual Regression")
struct GatewayCardVisualRegressionSnapshotTests {
    private static let snapshotSize = CGSize(width: 860, height: 520)
    private static let snapshotDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("screenshots", isDirectory: true)
        .appendingPathComponent("20260318", isDirectory: true)
        .appendingPathComponent("codex-gateway", isDirectory: true)
        .path

    @Test("before and after gateway drag-add snapshots")
    func gatewayDragAddSnapshots() {
        let beforeHost = makeHost(beforeStateView)
        let afterHost = makeHost(afterStateView)

        let beforeFailure = withSnapshotTesting(record: .failed) {
            verifySnapshot(
                of: beforeHost,
                as: .image(size: Self.snapshotSize),
                named: "20260318-codex-gateway-drag-add-before-v01",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        let afterFailure = withSnapshotTesting(record: .failed) {
            verifySnapshot(
                of: afterHost,
                as: .image(size: Self.snapshotSize),
                named: "20260318-codex-gateway-drag-add-after-v01",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(beforeFailure == nil)
        #expect(afterFailure == nil)
    }

    private var beforeStateView: some View {
        HStack(alignment: .top, spacing: 14) {
            accountCard(title: "dzurillaisadore@gmail.com", subtitle: "Pro plan", selected: true)

            gatewayCard(
                title: "网关 1",
                countText: "0 个成员",
                targeted: false,
                members: []
            )
        }
        .padding(20)
    }

    private var afterStateView: some View {
        HStack(alignment: .top, spacing: 14) {
            accountCard(title: "dzurillaisadore@gmail.com", subtitle: "Pro plan", selected: false)

            gatewayCard(
                title: "网关 1",
                countText: "2 个成员",
                targeted: true,
                members: [
                    ("dzurillaisadore@gmail.com", "dzurillaisadore@gmail.com"),
                    ("work-relay", "relay@company.com")
                ]
            )
        }
        .padding(20)
    }

    private func accountCard(title: String, subtitle: String, selected: Bool) -> some View {
        AccountSummaryCard(presentation: selected ? .selected : .neutral) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Codex")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }
        }
        .frame(width: 280, alignment: .leading)
    }

    private func gatewayCard(
        title: String,
        countText: String,
        targeted: Bool,
        members: [(String, String)]
    ) -> some View {
        AccountSummaryCard(presentation: targeted ? .selected : .neutral) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    Text(countText)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    Spacer(minLength: 0)
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }

                ForEach(Array(members.enumerated()), id: \.offset) { _, member in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.0)
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.Colors.Text.primary)
                                .lineLimit(1)
                            Text(member.1)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.Status.error)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.Background.surface.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .frame(width: 520, alignment: .leading)
    }

    private func makeHost(_ view: some View) -> NSHostingController<AnyView> {
        let rootView = AnyView(
            view
                .frame(width: Self.snapshotSize.width, height: Self.snapshotSize.height, alignment: .topLeading)
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
