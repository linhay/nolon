import Foundation

public struct CodexBinaryReleaseNotesData: Equatable, Sendable {
    public let title: String
    public let versionText: String
    public let subtitleText: String?
    public let notesMarkdown: String?
    public let emptyText: String
    public let actionTitle: String?
    public let actionURL: URL?

    public init(
        title: String,
        versionText: String,
        subtitleText: String?,
        notesMarkdown: String?,
        emptyText: String = NSLocalizedString(
            "codex.binary.release_notes.empty",
            value: "Release notes are not available for this version yet.",
            comment: "Release notes empty"
        ),
        actionTitle: String? = NSLocalizedString(
            "codex.binary.release_notes.open_github",
            value: "Open on GitHub",
            comment: "Open release on GitHub"
        ),
        actionURL: URL?
    ) {
        self.title = title
        self.versionText = versionText
        self.subtitleText = subtitleText
        self.notesMarkdown = notesMarkdown
        self.emptyText = emptyText
        self.actionTitle = actionTitle
        self.actionURL = actionURL
    }
}
