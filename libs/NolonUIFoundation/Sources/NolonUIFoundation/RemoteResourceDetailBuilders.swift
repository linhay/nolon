import Foundation

public enum RemoteResourceDetailBuilders {
    public static func versionSubtitle(version: String, createdAt: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: createdAt).formatted(date: .abbreviated, time: .omitted)
        return date.isEmpty ? version : "\(version) • \(date)"
    }

    public static func descriptionSection(summary: String?) -> RemoteResourceDetailData.Section? {
        guard let summary, !summary.isEmpty else { return nil }
        return .markdown(
            id: "summary",
            title: NSLocalizedString(
                "remote.detail.description",
                value: "Description",
                comment: "Remote resource detail description title"
            ),
            content: summary
        )
    }

    public static func changelogSection(changelog: String?) -> RemoteResourceDetailData.Section? {
        guard let changelog, !changelog.isEmpty else { return nil }
        return .markdown(
            id: "changelog",
            title: NSLocalizedString(
                "remote.detail.changelog",
                value: "Changelog",
                comment: "Remote resource detail changelog title"
            ),
            content: changelog
        )
    }
}
