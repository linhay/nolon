import XCTest
import ProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class SkillInstallerTests: XCTestCase {
    var fixture: TestFixture!
    var repository: SkillRepository!
    var installer: SkillInstaller!
    
    override func setUpWithError() throws {
        fixture = try TestFixture()
        repository = SkillRepository(nolonManager: fixture.nolonManager)
        installer = SkillInstaller(
            repository: repository,
            settings: fixture.providerSettings,
            nolonManager: fixture.nolonManager
        )
    }
    
    override func tearDownWithError() throws {
        fixture.cleanup()
    }
    
    func testInstallSkill_Symlink() throws {
        // 1. Setup sample skill
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        
        // 2. Import to global storage
        let skill = try repository.importSkill(from: sourceURL)
        
        // 3. Install to provider
        try installer.install(skill: skill, to: provider)
        
        // 4. Verify
        let targetPath = "\(provider.defaultSkillsPath)/\(skill.id)"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: targetPath))
        
        // Check if it's a symlink
        let attributes = try fixture.fileManager.attributesOfItem(atPath: targetPath)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
        
        let destination = try fixture.fileManager.destinationOfSymbolicLink(atPath: targetPath)
        XCTAssertEqual(destination, skill.globalPath)
    }
    
    func testInstallSkill_Copy() throws {
        // 1. Setup sample skill
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        let provider = fixture.createProvider(name: "VSCode", method: .copy)
        
        // 2. Import to global storage
        let skill = try repository.importSkill(from: sourceURL)
        
        // 3. Install to provider
        try installer.install(skill: skill, to: provider)
        
        // 4. Verify
        let targetPath = "\(provider.defaultSkillsPath)/\(skill.id)"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: targetPath))
        
        // Check if it's a directory (not a symlink)
        let attributes = try fixture.fileManager.attributesOfItem(atPath: targetPath)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeDirectory)
        
        // Check content
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: "\(targetPath)/SKILL.md"))
    }
    
    func testUninstallSkill() throws {
        // 1. Setup and Install
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        let skill = try repository.importSkill(from: sourceURL)
        try installer.install(skill: skill, to: provider)
        
        let targetPath = "\(provider.defaultSkillsPath)/\(skill.id)"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: targetPath))
        
        // 2. Uninstall
        try installer.uninstall(skill: skill, from: provider)
        
        // 3. Verify
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: targetPath))
    }

    func testBDD_GivenInstalledSkill_WhenUninstalling_ThenProviderRemovedAndGlobalRemains() throws {
        // Given
        let sourceURL = try fixture.createSampleSkill(id: "keep-global", name: "Keep Global")
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        let skill = try repository.importSkill(from: sourceURL)
        try installer.install(skill: skill, to: provider)

        let providerPath = "\(provider.defaultSkillsPath)/\(skill.id)"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: providerPath))
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: skill.globalPath))

        // When
        try installer.uninstall(skill: skill, from: provider)

        // Then
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: providerPath))
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: skill.globalPath))
    }
    
    func testScanProvider() throws {
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)
        
        // 1. Create one installed skill
        let sourceURL = try fixture.createSampleSkill(id: "installed-skill", name: "Installed")
        let skill = try repository.importSkill(from: sourceURL)
        try installer.install(skill: skill, to: provider)
        
        // 2. Create one orphaned skill
        let orphanedPath = "\(provider.defaultSkillsPath)/orphaned-skill"
        try fixture.fileManager.createDirectory(atPath: orphanedPath, withIntermediateDirectories: true)
        
        // 3. Scan
        let states = try installer.scanProvider(provider: provider)
        
        // 4. Verify
        XCTAssertEqual(states.count, 2)
        
        let installedState = states.first { $0.skillName == "installed-skill" }
        XCTAssertEqual(installedState?.state, .installed)
        
        let orphanedState = states.first { $0.skillName == "orphaned-skill" }
        XCTAssertEqual(orphanedState?.state, .orphaned)
    }

    func testInstallLocal_WhenSourceIsGlobalPath() throws {
        // Prepare a skill already located in global path
        let sourceURL = try fixture.createSampleSkill(id: "global-skill", name: "Global Skill")
        let skill = try repository.importSkill(from: sourceURL)

        // localPath points to the same global location
        let provider = fixture.createProvider(name: "Cursor", method: .symlink)

        // Should not delete the source before copy; should simply reuse it
        XCTAssertNoThrow(try installer.installLocal(from: skill.globalPath, slug: skill.id, to: provider))

        let targetPath = "\(provider.defaultSkillsPath)/\(skill.id)"
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: targetPath))

        // Verify symlink points to the global path
        let attributes = try fixture.fileManager.attributesOfItem(atPath: targetPath)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
        let destination = try fixture.fileManager.destinationOfSymbolicLink(atPath: targetPath)
        XCTAssertEqual(destination, skill.globalPath)
    }
}
