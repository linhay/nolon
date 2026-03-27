import SwiftUI
import ProviderUsage
import NolonUI

struct CodexConfigEditorSheet: View {
    @Binding var draft: ProviderUsageEngine.CodexConfigEditorDraft?
    let errorMessage: String?
    let testSuccessMessage: String?
    let testErrorMessage: String?
    let isTestingUsageQuery: Bool
    let onCancel: () -> Void
    let onTest: () -> Void
    let onSave: () -> Void

    private var currentDraft: ProviderUsageEngine.CodexConfigEditorDraft? {
        draft
    }

    private var isRelayMode: Bool {
        guard let draft = currentDraft else { return false }
        switch draft.mode {
        case .newRelay:
            return true
        case .newAPIKey:
            return false
        case .edit:
            return draft.isRelay
        }
    }

    private var editorMode: ProviderUsageEngine.CodexConfigEditorMode? {
        currentDraft?.mode
    }

    private var title: String {
        guard let editorMode else {
            return NSLocalizedString("codex.accounts.config.title", value: "Codex Config", comment: "Codex config title")
        }
        return ProviderUsageEngine.codexConfigEditorTitle(for: editorMode)
    }

    private var subtitle: String? {
        guard let editorMode else { return nil }
        return ProviderUsageEngine.codexConfigEditorSubtitle(for: editorMode)
    }

    private var primaryActionTitle: String {
        guard let editorMode else {
            return NSLocalizedString("generic.save", value: "Save", comment: "Save")
        }
        return ProviderUsageEngine.codexConfigEditorPrimaryActionTitle(for: editorMode)
    }

    private var canRunTest: Bool {
        guard let draft = currentDraft else { return false }
        if isTestingUsageQuery {
            return false
        }
        guard draft.httpUsageEnabled else {
            return false
        }
        return !draft.httpUsageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSaveDraft: Bool {
        guard let draft = currentDraft else { return false }
        return !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func binding(_ keyPath: WritableKeyPath<ProviderUsageEngine.CodexConfigEditorDraft, String>) -> Binding<String> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? "" },
            set: { draft?[keyPath: keyPath] = $0 }
        )
    }

    private var httpUsageEnabledBinding: Binding<Bool> {
        Binding(
            get: { draft?.httpUsageEnabled ?? false },
            set: { draft?.httpUsageEnabled = $0 }
        )
    }

    private var httpMethodRawValueBinding: Binding<String> {
        Binding(
            get: { draft?.httpUsageMethod.rawValue ?? CodexHTTPMethod.get.rawValue },
            set: { draft?.httpUsageMethod = CodexHTTPMethod(rawValue: $0) ?? .get }
        )
    }

    var body: some View {
        Group {
            if currentDraft != nil {
                NolonUI.CodexConfigEditorSheetView(
                    title: title,
                    subtitle: subtitle,
                    primaryActionTitle: primaryActionTitle,
                    errorMessage: errorMessage,
                    testSuccessMessage: testSuccessMessage,
                    testErrorMessage: testErrorMessage,
                    isRelayMode: isRelayMode,
                    isTestingUsageQuery: isTestingUsageQuery,
                    canRunTest: canRunTest,
                    canSaveDraft: canSaveDraft,
                    httpMethods: CodexHTTPMethod.allCases.map(\.rawValue),
                    selectedHTTPMethod: httpMethodRawValueBinding,
                    name: binding(\.name),
                    apiKey: binding(\.apiKey),
                    baseURL: binding(\.baseURL),
                    modelProvider: binding(\.modelProvider),
                    queryParamsText: binding(\.queryParamsText),
                    headersText: binding(\.headersText),
                    httpUsageEnabled: httpUsageEnabledBinding,
                    httpUsageURL: binding(\.httpUsageURL),
                    httpUsageTimeoutSeconds: binding(\.httpUsageTimeoutSeconds),
                    httpUsageHeadersText: binding(\.httpUsageHeadersText),
                    httpUsageBody: binding(\.httpUsageBody),
                    httpUsageOverrideBaseURL: binding(\.httpUsageOverrideBaseURL),
                    httpUsageOverrideAPIKey: binding(\.httpUsageOverrideAPIKey),
                    httpUsageOverrideAccessToken: binding(\.httpUsageOverrideAccessToken),
                    httpUsageOverrideUserID: binding(\.httpUsageOverrideUserID),
                    httpUsagePlanPath: binding(\.httpUsagePlanPath),
                    httpUsageCreditsRemainingPath: binding(\.httpUsageCreditsRemainingPath),
                    httpUsageUsedPath: binding(\.httpUsageUsedPath),
                    httpUsageTotalPath: binding(\.httpUsageTotalPath),
                    httpUsageCostTodayPath: binding(\.httpUsageCostTodayPath),
                    httpUsageCostLast30DaysPath: binding(\.httpUsageCostLast30DaysPath),
                    httpUsageErrorMessagePath: binding(\.httpUsageErrorMessagePath),
                    onCancel: onCancel,
                    onTest: onTest,
                    onSave: onSave
                )
            }
        }
    }
}
