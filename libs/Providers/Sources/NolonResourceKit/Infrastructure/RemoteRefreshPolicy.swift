import Foundation

public enum RemoteRefreshPolicy {
    /// Delay before refreshing installed state after remote install.
    public static let installPropagationDelay: TimeInterval = 0.35

    /// Delay before presenting follow-up UI that depends on async repository scan results.
    public static let repositorySelectionDelay: TimeInterval = 0.35
}
