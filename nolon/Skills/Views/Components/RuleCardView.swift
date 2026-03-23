import SwiftUI
import NolonUI
import NolonUIFoundation

struct RuleInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let preview: String
    let relativePath: String
    let path: String
}

struct RuleCardView: View {
    let rule: RuleInfo
    let searchText: String
    let onReveal: () -> Void
    let onDelete: () async -> Void
    let onTap: () -> Void

    var body: some View {
        NolonUI.RuleCardView(
            rule: foundationModel,
            searchText: searchText,
            onReveal: onReveal,
            onDelete: onDelete,
            onTap: onTap
        ) { rule in
            debugPageMarkerMenuItem(
                [
                    PageMarkerItem(title: NSLocalizedString("tab.rules", value: "Rules", comment: "Rules tab")),
                    PageMarkerItem(title: rule.name)
                ]
            )
        }
    }

    private var foundationModel: NolonUIFoundation.RuleInfo {
        NolonUIFoundation.RuleInfo(
            id: rule.id,
            name: rule.name,
            preview: rule.preview,
            relativePath: rule.relativePath,
            path: rule.path
        )
    }
}
