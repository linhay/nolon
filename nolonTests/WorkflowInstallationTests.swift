import XCTest
@testable import nolon

@MainActor
final class WorkflowInstallationTests: XCTestCase {
    var fixture: TestFixture!
    var repository: SkillRepository!
    var installer: SkillInstaller!
    var viewModel: ProviderDetailGridViewModel!
    
    override func setUpWithError() throws {
        fixture = try TestFixture()
        repository = SkillRepository(fileManager: fixture.fileManager, nolonManager: fixture.nolonManager)
        installer = SkillInstaller(
            fileManager: fixture.fileManager,
            repository: repository,
            settings: fixture.providerSettings,
            nolonManager: fixture.nolonManager
        )
    }
    
    override func tearDownWithError() throws {
        fixture.cleanup()
    }
    
    func testInstallWorkflow_FromSkill() throws {
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        let skill = try repository.importSkill(from: sourceURL)
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        
        try installer.installWorkflow(skill: skill, to: provider)
        
        let workflowPath = "\(provider.workflowPath)/\(skill.id).md"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: workflowPath))
        
        let attributes = try fixture.fileManager.attributesOfItem(atPath: workflowPath)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
    }
    
    func testUninstallWorkflow() throws {
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        let skill = try repository.importSkill(from: sourceURL)
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        try installer.installWorkflow(skill: skill, to: provider)
        
        let workflowPath = "\(provider.workflowPath)/\(skill.id).md"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: workflowPath))
        
        try installer.uninstallWorkflow(skill: skill, from: provider)
        
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: workflowPath))
    }
    
    func testInstallRemoteWorkflow() throws {
        let tempWorkflowContent = """
        ---
        name: Remote Workflow
        description: A remote workflow for testing
        version: 1.0.0
        ---
        
        # Remote Workflow Content
        This is a test workflow from remote source.
        """
        
        let tempDir = fixture.tempRoot.appendingPathComponent("remote-workflows")
        try fixture.fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempWorkflowFile = tempDir.appendingPathComponent("remote-workflow.md")
        try tempWorkflowContent.write(to: tempWorkflowFile, atomically: true, encoding: .utf8)
        
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        
        try installer.installRemoteWorkflow(fileURL: tempWorkflowFile, slug: "remote-workflow", to: provider)
        
        let installedPath = "\(provider.workflowPath)/remote-workflow.md"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: installedPath))
        
        let installedContent = try String(contentsOfFile: installedPath, encoding: .utf8)
        XCTAssertTrue(installedContent.contains("Remote Workflow Content"))
        
        let originFile = "\(provider.workflowPath)/.clawdhub_workflows"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: originFile))
    }
    
    func testInstallRemoteWorkflow_OverwriteExisting() throws {
        let tempDir = fixture.tempRoot.appendingPathComponent("remote-workflows")
        try fixture.fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let v1Content = "# Version 1"
        let v1File = tempDir.appendingPathComponent("workflow-v1.md")
        try v1Content.write(to: v1File, atomically: true, encoding: .utf8)
        
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        try installer.installRemoteWorkflow(fileURL: v1File, slug: "test-workflow", to: provider)
        
        let v2Content = "# Version 2"
        let v2File = tempDir.appendingPathComponent("workflow-v2.md")
        try v2Content.write(to: v2File, atomically: true, encoding: .utf8)
        
        try installer.installRemoteWorkflow(fileURL: v2File, slug: "test-workflow", to: provider)
        
        let installedPath = "\(provider.workflowPath)/test-workflow.md"
        let installedContent = try String(contentsOfFile: installedPath, encoding: .utf8)
        XCTAssertEqual(installedContent, v2Content)
    }
    
    func testViewModel_LoadWorkflows() async throws {
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        
        let sourceURL = try fixture.createSampleSkill(id: "skill-1", name: "Skill 1")
        let skill = try repository.importSkill(from: sourceURL)
        try installer.installWorkflow(skill: skill, to: provider)
        
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)
        viewModel.repository = repository
        viewModel.installer = installer
        
        await viewModel.updateProvider(provider)
        
        XCTAssertEqual(viewModel.workflows.count, 1)
        XCTAssertEqual(viewModel.workflows.first?.id, "skill-1")
    }
    
    func testViewModel_InstallRemoteWorkflow() async throws {
        let tempDir = fixture.tempRoot.appendingPathComponent("remote")
        try fixture.fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let workflowFile = tempDir.appendingPathComponent("remote.md")
        try "# Remote".write(to: workflowFile, atomically: true, encoding: .utf8)
        
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)
        viewModel.repository = repository
        viewModel.installer = installer
        
        try installer.installRemoteWorkflow(fileURL: workflowFile, slug: "remote", to: provider)
        
        await viewModel.loadData()
        
        XCTAssertEqual(viewModel.workflows.count, 1)
        XCTAssertEqual(viewModel.workflows.first?.id, "remote")
    }

    func testViewModel_InstallWorkflow_FromLocalPath() async throws {
        let tempDir = fixture.tempRoot.appendingPathComponent("local-workflows")
        try fixture.fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let workflowFile = tempDir.appendingPathComponent("local.md")
        try "# Local Workflow".write(to: workflowFile, atomically: true, encoding: .utf8)

        let remoteWorkflow = RemoteWorkflow(
            slug: "local",
            displayName: "Local Workflow",
            summary: nil,
            latestVersion: nil,
            updatedAt: Date(),
            downloads: nil,
            stars: nil,
            usages: nil,
            localPath: workflowFile.path
        )

        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)
        viewModel.repository = repository
        viewModel.installer = installer

        await viewModel.installRemoteWorkflow(remoteWorkflow, to: provider)

        let installedPath = "\(provider.workflowPath)/local.md"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: installedPath))
    }
    
    func testViewModel_DeleteWorkflow() async throws {
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        let skill = try repository.importSkill(from: sourceURL)
        try installer.installWorkflow(skill: skill, to: provider)
        
        viewModel = ProviderDetailGridViewModel(provider: provider, settings: fixture.providerSettings)
        viewModel.repository = repository
        viewModel.installer = installer
        await viewModel.updateProvider(provider)
        
        XCTAssertEqual(viewModel.workflows.count, 1)
        
        guard let workflow = viewModel.workflows.first else {
            XCTFail("Expected workflow to exist")
            return
        }
        await viewModel.deleteWorkflow(workflow)
        
        XCTAssertEqual(viewModel.workflows.count, 0)
    }
    
    func testInstallWorkflow_WorkflowDirectoryNotExist() throws {
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        let skill = try repository.importSkill(from: sourceURL)
        
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        let workflowPath = provider.workflowPath
        
        if fixture.fileManager.fileExists(atPath: workflowPath) {
            try fixture.fileManager.removeItem(atPath: workflowPath)
        }
        
        XCTAssertNoThrow(try installer.installWorkflow(skill: skill, to: provider))
        
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: workflowPath))
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: "\(workflowPath)/\(skill.id).md"))
    }
    
    func testUninstallWorkflow_FileNotExist() throws {
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        let skill = try repository.importSkill(from: sourceURL)
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        
        XCTAssertNoThrow(try installer.uninstallWorkflow(skill: skill, from: provider))
    }
}
