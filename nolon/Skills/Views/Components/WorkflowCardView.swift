import SwiftUI
import NolonUI
import NolonUIFoundation
import NolonResourceKit

enum WorkflowSource: String, CaseIterable {
    case skill
    case user
    case mcp
    case unknown
}

struct WorkflowInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let path: String
    let source: WorkflowSource
}

extension WorkflowSource {
    init(kind: WorkflowSourceKind) {
        switch kind {
        case .skill:
            self = .skill
        case .user:
            self = .user
        case .mcp:
            self = .mcp
        case .unknown:
            self = .unknown
        }
    }
}

struct WorkflowCardView: View {
    let workflow: WorkflowInfo
    let searchText: String
    let onReveal: () -> Void
    let onDelete: () async -> Void
    let onTap: () -> Void

    var body: some View {
        NolonUI.WorkflowCardView(
            workflow: foundationModel,
            searchText: searchText,
            onReveal: onReveal,
            onDelete: onDelete,
            onTap: onTap
        ) { workflow in
            debugPageMarkerMenuItem(
                [
                    PageMarkerItem(title: NSLocalizedString("tab.workflows", comment: "Workflows")),
                    PageMarkerItem(title: workflow.name)
                ]
            )
        }
    }

    private var foundationModel: NolonUIFoundation.WorkflowInfo {
        NolonUIFoundation.WorkflowInfo(
            id: workflow.id,
            name: workflow.name,
            description: workflow.description,
            path: workflow.path,
            source: workflow.source.foundationSource
        )
    }
}

private extension WorkflowSource {
    var foundationSource: NolonUIFoundation.WorkflowSource {
        switch self {
        case .skill:
            return .skill
        case .user:
            return .user
        case .mcp:
            return .mcp
        case .unknown:
            return .unknown
        }
    }
}
