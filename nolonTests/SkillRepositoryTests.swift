import XCTest
@testable import nolon

@MainActor
final class SkillRepositoryTests: XCTestCase {
    var fixture: TestFixture!
    var repository: SkillRepository!
    
    override func setUpWithError() throws {
        fixture = try TestFixture()
        repository = SkillRepository(fileManager: fixture.fileManager, nolonManager: fixture.nolonManager)
    }
    
    override func tearDownWithError() throws {
        fixture.cleanup()
    }
    
    func testListSkills_EmptyRepository() throws {
        let skills = try repository.listSkills()
        XCTAssertTrue(skills.isEmpty)
    }
    
    func testImportSkill_Success() throws {
        // Given
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        
        // When
        let skill = try repository.importSkill(from: sourceURL)
        
        // Then
        XCTAssertEqual(skill.id, "test-skill")
        XCTAssertEqual(skill.name, "Test Skill")
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: skill.globalPath))
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: "\(skill.globalPath)/SKILL.md"))
    }
    
    func testImportSkill_AlreadyExists() throws {
        // Given
        let sourceURL = try fixture.createSampleSkill(id: "test-skill", name: "Test Skill")
        _ = try repository.importSkill(from: sourceURL)
        
        // When/Then
        XCTAssertThrowsError(try repository.importSkill(from: sourceURL)) { error in
            XCTAssertTrue(error is SkillError)
        }
    }
    
    func testListSkills_WithSkills() throws {
        // Given
        let s1 = try fixture.createSampleSkill(id: "skill-1", name: "S1")
        let s2 = try fixture.createSampleSkill(id: "skill-2", name: "S2")
        _ = try repository.importSkill(from: s1)
        _ = try repository.importSkill(from: s2)
        
        // When
        let skills = try repository.listSkills()
        
        // Then
        XCTAssertEqual(skills.count, 2)
        XCTAssertTrue(skills.contains { $0.id == "skill-1" })
        XCTAssertTrue(skills.contains { $0.id == "skill-2" })
    }
    
    func testDeleteSkill_Success() throws {
        // Given
        let sourceURL = try fixture.createSampleSkill(id: "to-delete", name: "Delete Me")
        let skill = try repository.importSkill(from: sourceURL)
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: skill.globalPath))
        
        // When
        try repository.deleteSkill(id: "to-delete")
        
        // Then
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: skill.globalPath))
    }
    
    func testCreateGlobalWorkflow() throws {
        // Given
        let sourceURL = try fixture.createSampleSkill(id: "workflow-test", name: "Workflow Skill")
        let skill = try repository.importSkill(from: sourceURL)
        
        // When
        let workflowPath = try repository.createGlobalWorkflow(for: skill)
        
        // Then
        XCTAssertTrue(fixture.fileManager.fileExists(atPath: workflowPath))
        let content = try String(contentsOfFile: workflowPath)
        XCTAssertTrue(content.contains("Workflow Skill"))
    }
    
    func testMetadataPersistence() throws {
        // Given
        let skillId = "meta-test"
        let date = Date(timeIntervalSince1970: 1000)
        
        // When
        try repository.updateMetadata(for: skillId, lastUpdated: date, sourceURL: "https://github.com/test")
        let metadata = try repository.loadMetadata()
        
        // Then
        XCTAssertNotNil(metadata.skills[skillId])
        XCTAssertEqual(metadata.skills[skillId]?.id, skillId)
        XCTAssertEqual(metadata.skills[skillId]?.sourceURL, "https://github.com/test")
        // Use time interval to avoid tiny fractional differences if any
        XCTAssertEqual(metadata.skills[skillId]?.lastUpdated.timeIntervalSince1970, date.timeIntervalSince1970)
    }
}
