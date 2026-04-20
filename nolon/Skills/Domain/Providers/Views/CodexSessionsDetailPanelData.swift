import Foundation
import NolonUIFoundation

struct CodexSessionsDetailPanelData: Equatable {
    let threadIDText: String
    let threadIDCopyValue: String?
    let providerText: String
    let startedAtText: String
    let lastActivityText: String
    let projectPath: String?
    let groupTitle: String?
    let summary: String?
    let usage: CodexSessionsDetailUsageData?
    let rolloutPath: String
    let stateRowCount: Int
    let metadataItems: [CodexSessionsMetadataItemData]
    let statusTexts: [String]
    let resumeCommand: String?
    let shareData: CodexSessionsShareData?
    let rowData: CodexSessionsRowData
}

struct CodexSessionsDetailUsageData: Equatable {
    let totalText: String
    let inputText: String?
    let outputText: String?
    let cachedText: String?
    let isPlaceholder: Bool
}

struct CodexSessionsDetailTimelineData: Equatable {
    let startedAtText: String
    let lastActivityText: String
}
