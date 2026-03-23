import SwiftUI
import NolonUI
import NolonUIFoundation

enum AgentDocKind: String, Sendable {
    case override
    case base
}

struct AgentDocInfo: Identifiable, Hashable, Sendable {
    let id: String
    let fileName: String
    let path: String
    let preview: String
    let kind: AgentDocKind
}

struct AgentDocCardView: View {
    let doc: AgentDocInfo
    let searchText: String
    let onReveal: () -> Void
    let onDelete: () async -> Void
    let onTap: () -> Void

    var body: some View {
        NolonUI.AgentDocCardView(
            doc: foundationModel,
            searchText: searchText,
            onReveal: onReveal,
            onDelete: onDelete,
            onTap: onTap
        ) { doc in
            debugPageMarkerMenuItem(
                [
                    PageMarkerItem(title: NSLocalizedString("tab.agents", value: "Agents", comment: "Agents tab")),
                    PageMarkerItem(title: doc.fileName)
                ]
            )
        }
    }

    private var foundationModel: NolonUIFoundation.AgentDocInfo {
        NolonUIFoundation.AgentDocInfo(
            id: doc.id,
            fileName: doc.fileName,
            path: doc.path,
            preview: doc.preview,
            kind: doc.kind == .override ? .override : .base
        )
    }
}
