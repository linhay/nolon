import AppKit
import SwiftUI
import Testing
import WebKit
import ProviderUsage
@testable import nolon

@MainActor
@Suite("Claude Account Editor Sheet Snapshot")
struct ClaudeAccountEditorSheetSnapshotTests {
    private static let snapshotSize = CGSize(width: 860, height: 760)

    @Test("create editor embeds bidirectional json web editor")
    func createEditorEmbedsBidirectionalJSONWebEditor() {
        let host = makeHost(
            ClaudeAccountEditorSheet(
                draft: .constant(makeCreateDraft()),
                errorMessage: nil,
                onCancel: {},
                onSave: {}
            )
        )

        #expect(findDescendant(in: host.view, as: WKWebView.self) != nil)
    }

    @Test("edit editor preloads fields while embedding json web editor")
    func editEditorPreloadsFieldsWhileEmbeddingJSONWebEditor() {
        let host = makeHost(
            ClaudeAccountEditorSheet(
                draft: .constant(makeEditDraft()),
                errorMessage: "Credential cannot be empty.",
                onCancel: {},
                onSave: {}
            )
        )

        #expect(findDescendant(in: host.view, as: WKWebView.self) != nil)
        #expect(allTextValues(in: host.view).contains("Relay Claude"))
        #expect(allTextValues(in: host.view).contains("https://relay.example.com/v1"))
    }

    @Test("BDD: Given edit draft when rendering credential field then it uses plain text input")
    func editEditorUsesPlainTextCredentialField() {
        let host = makeHost(
            ClaudeAccountEditorSheet(
                draft: .constant(makeEditDraft()),
                errorMessage: nil,
                onCancel: {},
                onSave: {}
            )
        )

        #expect(findDescendant(in: host.view, as: NSSecureTextField.self) == nil)
        #expect(editablePlainTextValues(in: host.view).contains("sk-ant-api-visible"))
    }

    private func makeCreateDraft() -> ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft {
        ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft(
            mode: .create,
            accountID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "",
            credentialType: .authToken,
            credentialValue: "sk-ant-create",
            baseURL: "https://api.anthropic.com",
            anthropicModel: "",
            anthropicReasoningModel: "",
            anthropicDefaultHaikuModel: "",
            anthropicDefaultSonnetModel: "",
            anthropicDefaultOpusModel: ""
        )
    }

    private func makeEditDraft() -> ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft {
        ProviderUsageAccountsViewModel.ClaudeState.AccountEditorDraft(
            mode: .edit,
            accountID: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            name: "Relay Claude",
            credentialType: .apiKey,
            credentialValue: "sk-ant-api-visible",
            baseURL: "https://relay.example.com/v1",
            anthropicModel: "claude-primary",
            anthropicReasoningModel: "claude-reasoning",
            anthropicDefaultHaikuModel: "claude-haiku",
            anthropicDefaultSonnetModel: "claude-sonnet",
            anthropicDefaultOpusModel: "claude-opus"
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
