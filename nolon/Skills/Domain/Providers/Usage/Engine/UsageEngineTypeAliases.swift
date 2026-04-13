import Foundation
import NolonUIFoundation

enum CodexAccountInteractionState: Equatable, Sendable {
    case inactive
    case active
    case awaitingConfirmation
    case switching

    var allowsActivationRequest: Bool {
        self == .inactive
    }

    func presentationState(
        isBatchSelected: Bool,
        selectableAccountCount: Int
    ) -> CodexAccountCardPresentationState {
        switch self {
        case .active:
            return .active
        case .switching:
            return .switching
        case .inactive, .awaitingConfirmation:
            if isBatchSelected, selectableAccountCount > 1 {
                return .selected
            }
            return .inactive
        }
    }
}

typealias CodexAccountDisplayState = ProviderUsageEngine.CodexAccountDisplayState
typealias CodexAccountGroupingOption = ProviderUsageEngine.CodexAccountGroupingOption
typealias CodexAccountSortOption = ProviderUsageEngine.CodexAccountSortOption
typealias CodexSortDirection = ProviderUsageEngine.CodexSortDirection
typealias UsageAccountLayoutMode = ProviderUsageEngine.UsageAccountLayoutMode
typealias CodexPrimaryHeaderAction = ProviderUsageEngine.CodexPrimaryHeaderAction
typealias CodexAccountDisplaySection = ProviderUsageEngine.CodexAccountDisplaySection
typealias CodexConfigEditorMode = ProviderUsageEngine.CodexConfigEditorMode
typealias CodexConfigEditorDraft = ProviderUsageEngine.CodexConfigEditorDraft
typealias CodexImportCandidate = ProviderUsageEngine.CodexImportCandidate
typealias CodexImportConnectionTestStatus = ProviderUsageEngine.CodexImportConnectionTestStatus
typealias CodexImportCandidateSection = ProviderUsageEngine.CodexImportCandidateSection
typealias CodexImportDestinationOption = ProviderUsageEngine.CodexImportDestinationOption
typealias CodexAddSource = ProviderUsageEngine.CodexAddSource
typealias UsageEngineTokenTrendRange = ProviderUsageEngine.TokenTrendRange
