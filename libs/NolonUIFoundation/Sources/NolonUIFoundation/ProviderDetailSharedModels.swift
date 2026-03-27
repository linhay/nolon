import Foundation

public struct ProviderResourceHealthSummaryData {
    public let warningTitle: String
    public let orphanedSkillsText: String?
    public let orphanedSkillsHelp: String?
    public let brokenSkillsText: String?
    public let unknownWorkflowsText: String?
    public let mcpUpdateText: String?

    public init(
        warningTitle: String,
        orphanedSkillsText: String?,
        orphanedSkillsHelp: String?,
        brokenSkillsText: String?,
        unknownWorkflowsText: String?,
        mcpUpdateText: String?
    ) {
        self.warningTitle = warningTitle
        self.orphanedSkillsText = orphanedSkillsText
        self.orphanedSkillsHelp = orphanedSkillsHelp
        self.brokenSkillsText = brokenSkillsText
        self.unknownWorkflowsText = unknownWorkflowsText
        self.mcpUpdateText = mcpUpdateText
    }
}

public struct ProviderCodexLinkedHintData {
    public let title: String
    public let pathText: String
    public let actionTitle: String

    public init(
        title: String,
        pathText: String,
        actionTitle: String
    ) {
        self.title = title
        self.pathText = pathText
        self.actionTitle = actionTitle
    }
}

public struct ProviderCodexXcodeNoticeData {
    public let title: String
    public let description: String

    public init(title: String, description: String) {
        self.title = title
        self.description = description
    }
}
