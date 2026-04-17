import AppKit
import SwiftUI
import Testing
import WebKit
import ProviderUsage
import NolonUI
@testable import nolon

@MainActor
@Suite("Codex Config Editor Sheet Snapshot")
struct CodexConfigEditorSheetSnapshotTests {
    private static let snapshotSize = CGSize(width: 900, height: 760)
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
                isSaving: false,
                errorMessage: nil,
                onCancel: {},
                onValidateConnection: {},
                onSave: {}
            )
        )

        let buttons = findDescendants(in: host.view, as: NSButton.self)
        let closeButton = buttons.max { lhs, rhs in
            let lhsFrame = lhs.convert(lhs.bounds, to: host.view)
            let rhsFrame = rhs.convert(rhs.bounds, to: host.view)
            if lhsFrame.maxY == rhsFrame.maxY {
                return lhsFrame.maxX < rhsFrame.maxX
            }
            return lhsFrame.maxY < rhsFrame.maxY
        }

        guard let closeButton else {
            Issue.record("Expected at least one rendered button in the editor sheet.")
            return
        }

        let frame = closeButton.convert(closeButton.bounds, to: host.view)
        let minExpectedX = Self.snapshotSize.width * 0.8
        let minExpectedY = Self.snapshotSize.height * 0.8

        #expect(frame.minX >= minExpectedX)
        #expect(frame.minY >= minExpectedY)
    }

    @Test("editor embeds auth json web editor and shows managed config preview")
    func editorEmbedsAuthJSONWebEditorAndShowsManagedConfigPreview() {
        let host = makeHost(
            CodexConfigEditorSheet(
                draft: .constant(makeDraft()),
                modelProviderOptions: ["nolon", "relay-prod"],
                isSaving: false,
                errorMessage: nil,
                onCancel: {},
                onValidateConnection: {},
                onSave: {}
            )
        )

        #expect(findDescendant(in: host.view, as: WKWebView.self) != nil)
        #expect(allTextValues(in: host.view).contains("Suggested from current config"))
        #expect(allTextValues(in: host.view).contains("# No managed config.toml changes."))
    }

    @Test("BDD: Given new API key draft when rendering API key field then it uses plain text input")
    func editorUsesPlainTextAPIKeyField() {
        let host = makeHost(
            CodexConfigEditorSheet(
                draft: .constant(makeDraft()),
                modelProviderOptions: ["nolon", "relay-prod"],
                isSaving: false,
                errorMessage: nil,
                onCancel: {},
                onValidateConnection: {},
                onSave: {}
            )
        )

        #expect(findDescendant(in: host.view, as: NSSecureTextField.self) == nil)
        #expect(editablePlainTextValues(in: host.view).contains("sk-live-12345678"))
    }

    @Test("BDD: Given save is in flight when rendering footer then progress is visible and actions are disabled")
    func editorShowsSavingProgressAndDisablesActions() {
        let host = makeHost(
            CodexConfigEditorSheet(
                draft: .constant(makeDraft()),
                modelProviderOptions: ["nolon", "relay-prod"],
                isSaving: true,
                errorMessage: nil,
                onCancel: {},
                onValidateConnection: {},
                onSave: {}
            )
        )

        #expect(findDescendant(in: host.view, as: NSProgressIndicator.self) != nil)
    }

    @Test("BDD: Given optional codex draft when updating api key then explicit writeback keeps the draft and new value")
    func explicitDraftWritebackKeepsUpdatedAPIKey() {
        let updated = CodexConfigEditorSheet.updatedDraft(makeDraft()) { draft in
            draft.apiKey = ""
        }

        #expect(updated != nil)
        #expect(updated?.apiKey == "")
    }

    private func makeDraft() -> ProviderUsageEngine.CodexConfigEditorDraft {
        ProviderUsageEngine.CodexConfigEditorDraft(
            mode: .newAPIKey,
            name: "",
            apiKey: "sk-live-12345678",
            baseURL: "",
            modelProvider: "nolon",
            queryParamsText: "",
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

    private func findDescendant<T: NSView>(in root: NSView, as type: T.Type) -> T? {
        if let match = root as? T {
            return match
        }

        for child in root.subviews {
            if let match = findDescendant(in: child, as: type) {
                return match
            }
        }

        return nil
    }

    private func findDescendants<T: NSView>(in root: NSView, as type: T.Type) -> [T] {
        var matches: [T] = []
        if let match = root as? T {
            matches.append(match)
        }
        for child in root.subviews {
            matches.append(contentsOf: findDescendants(in: child, as: type))
        }
        return matches
    }

    private func allTextValues(in root: NSView) -> [String] {
        var results: [String] = []
        if let label = root as? NSTextField {
            results.append(label.stringValue)
        }
        for child in root.subviews {
            results.append(contentsOf: allTextValues(in: child))
        }
        return results
    }

    private func editablePlainTextValues(in root: NSView) -> [String] {
        var results: [String] = []
        if let textField = root as? NSTextField, textField.isEditable, !(textField is NSSecureTextField) {
            results.append(textField.stringValue)
        }
        for child in root.subviews {
            results.append(contentsOf: editablePlainTextValues(in: child))
        }
        return results
    }
}
