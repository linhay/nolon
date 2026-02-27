import Foundation
import ProviderCatalog
import STFilePath

public struct WorkflowBindingInstallResult: Sendable, Equatable {
    public let workflowFileName: String
    public let globalWorkflowPath: String
    public let providerWorkflowPath: String

    public init(workflowFileName: String, globalWorkflowPath: String, providerWorkflowPath: String) {
        self.workflowFileName = workflowFileName
        self.globalWorkflowPath = globalWorkflowPath
        self.providerWorkflowPath = providerWorkflowPath
    }
}

public struct WorkflowBindingUninstallResult: Sendable, Equatable {
    public let workflowFileName: String
    public let providerWorkflowPath: String
    public let removed: Bool

    public init(workflowFileName: String, providerWorkflowPath: String, removed: Bool) {
        self.workflowFileName = workflowFileName
        self.providerWorkflowPath = providerWorkflowPath
        self.removed = removed
    }
}

public final class WorkflowBindingService: @unchecked Sendable {
    private let manager: NolonManager

    public init(manager: NolonManager = .shared) {
        self.manager = manager
    }

    public func bindWorkflowFromSkill(
        skillID: String,
        providerWorkflowPath: STFolder
    ) throws -> WorkflowBindingInstallResult {
        let result = try SkillsRepositoryFacade.bindWorkflowFromSkill(
            skillID: skillID,
            providerWorkflowPath: providerWorkflowPath.url,
            nolonHome: manager.rootFolder.url
        )
        return WorkflowBindingInstallResult(
            workflowFileName: result.workflowFileName,
            globalWorkflowPath: result.globalWorkflowPath,
            providerWorkflowPath: result.providerWorkflowPath
        )
    }

    public func bindWorkflowFromMCP(
        mcpName: String,
        providerWorkflowPath: STFolder
    ) throws -> WorkflowBindingInstallResult {
        let result = try SkillsRepositoryFacade.bindWorkflowFromMCP(
            mcpName: mcpName,
            providerWorkflowPath: providerWorkflowPath.url,
            nolonHome: manager.rootFolder.url
        )
        return WorkflowBindingInstallResult(
            workflowFileName: result.workflowFileName,
            globalWorkflowPath: result.globalWorkflowPath,
            providerWorkflowPath: result.providerWorkflowPath
        )
    }

    public func unbindWorkflowFromSkill(
        skillID: String,
        providerWorkflowPath: STFolder
    ) throws -> WorkflowBindingUninstallResult {
        let result = try SkillsRepositoryFacade.unbindWorkflowFromSkill(
            skillID: skillID,
            providerWorkflowPath: providerWorkflowPath.url
        )
        return WorkflowBindingUninstallResult(
            workflowFileName: result.workflowFileName,
            providerWorkflowPath: result.providerWorkflowPath,
            removed: result.removed
        )
    }

    public func unbindWorkflowFromMCP(
        mcpName: String,
        providerWorkflowPath: STFolder
    ) throws -> WorkflowBindingUninstallResult {
        let result = try SkillsRepositoryFacade.unbindWorkflowFromMCP(
            mcpName: mcpName,
            providerWorkflowPath: providerWorkflowPath.url
        )
        return WorkflowBindingUninstallResult(
            workflowFileName: result.workflowFileName,
            providerWorkflowPath: result.providerWorkflowPath,
            removed: result.removed
        )
    }
}
