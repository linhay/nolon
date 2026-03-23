import NolonUI
import NolonUIFoundation
import NolonResourceKit

enum NolonUIAdapter {
    static func resourceMetaItems(_ items: [ResourceCardMetaItem]) -> [NolonUI.ResourceCardMetaItem] {
        items.map { item in
            switch item {
            case let .stars(value):
                return .stars(value)
            case let .downloads(value):
                return .downloads(value)
            case let .usages(value):
                return .usages(value)
            case let .installs(value):
                return .installs(value)
            case let .command(value):
                return .command(value)
            }
        }
    }
}

extension AgentDocInfo {
    var uiFoundationModel: NolonUIFoundation.AgentDocInfo {
        NolonUIFoundation.AgentDocInfo(
            id: id,
            fileName: fileName,
            path: path,
            preview: preview,
            kind: kind == .override ? .override : .base
        )
    }
}

extension RuleInfo {
    var uiFoundationModel: NolonUIFoundation.RuleInfo {
        NolonUIFoundation.RuleInfo(
            id: id,
            name: name,
            preview: preview,
            relativePath: relativePath,
            path: path
        )
    }
}

extension WorkflowSource {
    var uiFoundationSource: NolonUIFoundation.WorkflowSource {
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

extension WorkflowInfo {
    var uiFoundationModel: NolonUIFoundation.WorkflowInfo {
        NolonUIFoundation.WorkflowInfo(
            id: id,
            name: name,
            description: description,
            path: path,
            source: source.uiFoundationSource
        )
    }
}

extension ProviderDetailGridViewModel.McpCacheState {
    var uiCacheState: NolonUI.McpServerCardCacheState {
        switch self {
        case .notMigrated:
            return .notMigrated
        case .migratedUpToDate:
            return .migratedUpToDate
        case .migratedNeedsUpdate:
            return .migratedNeedsUpdate
        }
    }
}
