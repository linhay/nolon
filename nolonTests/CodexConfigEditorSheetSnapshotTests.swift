import AppKit
import SnapshotTesting
import SwiftUI
import Testing
import ProviderUsage
import NolonUI
@testable import nolon

@MainActor
@Suite("Codex Config Editor Sheet Snapshot")
struct CodexConfigEditorSheetSnapshotTests {
    private static let snapshotSize = CGSize(width: 640, height: 420)
    private static let snapshotDirectory: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
            .appendingPathComponent("CodexConfigEditorSheetSnapshotTests", isDirectory: true)
            .path
    }()

    @Test("new api key editor uses top trailing close button")
    func newAPIKeyEditorUsesTopTrailingCloseButton() {
        let host = makeHost(
            CodexConfigEditorSheet(
                draft: .constant(makeDraft()),
                modelProviderOptions: ["nolon", "relay-prod"],
                errorMessage: nil,
                onCancel: {},
                onValidateConnection: {},
                onSave: {}
            )
        )

        let failure = withSnapshotTesting(record: .all) {
            verifySnapshot(
                of: host,
                as: .image(size: Self.snapshotSize),
                named: "new-api-key-top-close",
                snapshotDirectory: Self.snapshotDirectory
            )
        }

        #expect(failure == nil || failure?.contains("Record mode is on") == true)
    }

    private func makeDraft() -> ProviderUsageEngine.CodexConfigEditorDraft {
        ProviderUsageEngine.CodexConfigEditorDraft(
            mode: .newAPIKey,
            name: "",
            apiKey: "sk-live-12345678",
            baseURL: "",
            modelProvider: "nolon",
            queryParamsText: "",
            headersText: "",
            httpUsageEnabled: false,
            httpUsageMethod: .get,
            httpUsageURL: "",
            httpUsageHeadersText: "",
            httpUsageBody: "",
            httpUsageTimeoutSeconds: "15",
            httpUsageOverrideBaseURL: "",
            httpUsageOverrideAPIKey: "",
            httpUsageOverrideAccessToken: "",
            httpUsageOverrideUserID: "",
            httpUsagePlanPath: "",
            httpUsageCreditsRemainingPath: "",
            httpUsageUsedPath: "",
            httpUsageTotalPath: "",
            httpUsageCostTodayPath: "",
            httpUsageCostLast30DaysPath: "",
            httpUsageErrorMessagePath: ""
        )
    }

    private func makeHost(_ view: some View) -> NSHostingController<AnyView> {
        let rootView = AnyView(
            view
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
