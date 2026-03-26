import ProviderUsage

enum CodexUsageCardPresentationPolicy {
    static func statusKind(for state: ProviderUsageEngine.CodexAccountDisplayState) -> UsageCardStatusKind {
        switch state {
        case .needsReauth, .failed:
            return .error
        case .healthy:
            return .healthy
        case .pending:
            return .pending
        }
    }

    static func actionLayout(needsReauth: Bool, hasLoginAction: Bool) -> UsageCardActionLayout {
        if needsReauth, hasLoginAction {
            return .dualEqualWidth
        }
        return .singleFullWidth
    }
}
