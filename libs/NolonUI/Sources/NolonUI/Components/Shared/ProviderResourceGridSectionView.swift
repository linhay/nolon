import SwiftUI

public enum ProviderResourceGridKind: Hashable, Sendable {
    case skills
    case workflows
    case rules
    case agents
}

public struct ProviderResourceGridSectionView<Content: View>: View {
    let isEmpty: Bool
    let searchText: String
    let kind: ProviderResourceGridKind?
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let noResultsTitle: String
    let noResultsSystemImage: String
    let noResultsDescription: String
    let columns: [GridItem]
    let content: () -> Content

    public init(
        isEmpty: Bool,
        searchText: String,
        kind: ProviderResourceGridKind? = nil,
        emptyTitle: String? = nil,
        emptySystemImage: String? = nil,
        emptyDescription: String? = nil,
        noResultsTitle: String = "No Results",
        noResultsSystemImage: String = "magnifyingglass",
        noResultsDescription: String,
        columns: [GridItem],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = isEmpty
        self.searchText = searchText
        self.kind = kind
        self.emptyTitle = emptyTitle ?? Self.defaultEmptyTitle(for: kind)
        self.emptySystemImage = emptySystemImage ?? Self.defaultEmptySystemImage(for: kind)
        self.emptyDescription = emptyDescription ?? Self.defaultEmptyDescription(for: kind)
        self.noResultsTitle = noResultsTitle
        self.noResultsSystemImage = noResultsSystemImage
        self.noResultsDescription = noResultsDescription
        self.columns = columns
        self.content = content
    }

    public var body: some View {
        ProviderGridContentScaffold(
            isEmpty: isEmpty,
            emptyTitle: searchText.isEmpty ? emptyTitle : noResultsTitle,
            emptySystemImage: searchText.isEmpty ? emptySystemImage : noResultsSystemImage,
            emptyDescription: searchText.isEmpty ? emptyDescription : noResultsDescription,
            columns: columns
        ) {
            content()
        }
    }

    nonisolated private static func defaultEmptyTitle(for kind: ProviderResourceGridKind?) -> String {
        switch kind {
        case .skills:
            return NSLocalizedString("skills.empty", value: "No Skills", comment: "No skills")
        case .workflows:
            return NSLocalizedString("workflows.empty", value: "No Workflows", comment: "No workflows")
        case .rules:
            return NSLocalizedString("rules.empty", value: "No Rules", comment: "No rules")
        case .agents:
            return NSLocalizedString("agents.empty", value: "No AGENTS.md Files", comment: "No agent docs")
        case nil:
            return NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No results")
        }
    }

    nonisolated private static func defaultEmptySystemImage(for kind: ProviderResourceGridKind?) -> String {
        switch kind {
        case .skills:
            return "square.grid.2x2"
        case .workflows:
            return "arrow.triangle.branch"
        case .rules:
            return "list.bullet.rectangle"
        case .agents:
            return "doc.text"
        case nil:
            return "tray"
        }
    }

    nonisolated private static func defaultEmptyDescription(for kind: ProviderResourceGridKind?) -> String {
        switch kind {
        case .skills:
            return NSLocalizedString("skills.empty_desc", value: "No skills installed in this provider", comment: "No skills in provider")
        case .workflows:
            return NSLocalizedString("workflows.empty_desc", value: "No workflows in this provider", comment: "No workflows in provider")
        case .rules:
            return NSLocalizedString("rules.empty_desc", value: "No rules in this provider", comment: "No rules in provider")
        case .agents:
            return NSLocalizedString("agents.empty_desc", value: "No AGENTS.md files found in Codex home", comment: "No agents docs")
        case nil:
            return NSLocalizedString("remote.search.no_results_desc", value: "No matching results found", comment: "No search results description")
        }
    }
}
