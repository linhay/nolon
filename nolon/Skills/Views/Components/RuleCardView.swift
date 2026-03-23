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
            rule: rule.uiFoundationModel,
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
}
