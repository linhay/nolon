import Foundation
import XCTest
@testable import nolon

/// Helper class for integration tests to manage temporary environment
@MainActor
final class TestFixture {
    let tempRoot: URL
    let fileManager: FileManager
    let testUserDefaults: UserDefaults
    let suiteName: String
    
    let nolonManager: NolonManager
    let providerSettings: ProviderSettings
    
    init() throws {
        self.fileManager = .default
        self.tempRoot = URL(fileURLWithPath: "/tmp/nolon-test-\(UUID().uuidString)")
        try? fileManager.removeItem(at: tempRoot)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        
        // Isolate UserDefaults
        self.suiteName = "nolon-test-\(UUID().uuidString)"
        self.testUserDefaults = UserDefaults(suiteName: suiteName)!
        
        // Setup NolonManager and ProviderSettings for testing
        self.nolonManager = NolonManager(fileManager: fileManager, rootURL: tempRoot)
        self.providerSettings = ProviderSettings(userDefaults: testUserDefaults, nolonManager: nolonManager)
    }
    
    func cleanup() {
        try? fileManager.removeItem(at: tempRoot)
        testUserDefaults.removePersistentDomain(forName: suiteName)
    }
    
    func createSampleSkill(id: String, name: String) throws -> URL {
        let skillDir = tempRoot.appendingPathComponent("sample-source/\(id)")
        try fileManager.createDirectory(at: skillDir, withIntermediateDirectories: true)
        
        let content = """
        ---
        name: \(name)
        description: A sample skill for testing
        version: 1.0.0
        ---
        
        Test content
        """
        
        try content.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        
        // Create subdirectories
        try fileManager.createDirectory(at: skillDir.appendingPathComponent("references"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: skillDir.appendingPathComponent("scripts"), withIntermediateDirectories: true)
        
        return skillDir
    }
    
    func createProvider(name: String, method: SkillInstallationMethod) -> Provider {
        let providerDir = tempRoot.appendingPathComponent("providers/\(name)")
        let workflowDir = tempRoot.appendingPathComponent("providers/\(name)-workflows")
        
        try? fileManager.createDirectory(at: providerDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: workflowDir, withIntermediateDirectories: true)
        
        return Provider(
            name: name,
            defaultSkillsPath: providerDir.path,
            workflowPath: workflowDir.path,
            installMethod: method
        )
    }
}
