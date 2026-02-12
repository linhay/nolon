import Foundation
import STFilePath
import Testing
@testable import NolonCoreCLIKit

@Suite("NolonLiveSkillsRepositoryService")
struct NolonSkillsRepositoryServiceTests {
    @Test("sync maps facade access token required to structured cli error")
    func syncMapsAccessTokenRequired() async {
        let service = NolonLiveSkillsRepositoryService()
        let plan = NolonGitImportPlan(
            source: "vercel/agent-skills",
            normalizedGitURL: "https://github.com/vercel/agent-skills.git",
            subpath: nil,
            providerHost: "github.com",
            owner: "vercel",
            repo: "agent-skills",
            localClonePath: FileManager.default.temporaryDirectory
                .appendingPathComponent("nolon-sync-\(UUID().uuidString)", isDirectory: true)
        )

        do {
            _ = try await service.syncGitRepository(
                plan: plan,
                accessToken: nil,
                pullStrategy: .ffOnly,
                credentialStrategy: .tokenOnly
            )
            Issue.record("Expected syncFailed access_token_required")
        } catch let error as NolonCoreCLIError {
            guard case let .syncFailed(code: code, message: _, detail: detail) = error else {
                Issue.record("Unexpected cli error: \(error)")
                return
            }
            #expect(code == "access_token_required")
            #expect(detail.credentialStrategy == .tokenOnly)
            #expect(detail.hasAccessToken == false)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("install skill creates symlink at provider path")
    func installSkillCreatesSymlink() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-install-\(UUID().uuidString)", isDirectory: true)
        let skillRoot = root.appendingPathComponent("skills/react-best-practices", isDirectory: true)
        let providerRoot = root.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: skillRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: providerRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try service.installSkill(
            skillPath: STPath(skillRoot),
            skillID: nil,
            providerPath: STFolder(providerRoot),
            installMethod: .symlink
        )

        #expect(result.skillID == "react-best-practices")
        #expect(result.installMethod == .symlink)

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: result.targetPath, isDirectory: &isDirectory))
        #expect((try? URL(fileURLWithPath: result.targetPath).resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true)
    }

    @Test("uninstall skill removes provider target")
    func uninstallSkillRemovesTarget() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-uninstall-\(UUID().uuidString)", isDirectory: true)
        let providerRoot = root.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: providerRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let target = providerRoot.appendingPathComponent("react-best-practices", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        let result = try service.uninstallSkill(skillID: "react-best-practices", providerPath: STFolder(providerRoot))
        #expect(result.removed == true)
        #expect(FileManager.default.fileExists(atPath: result.targetPath) == false)
    }

    @Test("install resource copies file to target path")
    func installResourceCopiesFile() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-resource-install-\(UUID().uuidString)", isDirectory: true)
        let sourceDir = root.appendingPathComponent("source", isDirectory: true)
        let targetDir = root.appendingPathComponent("provider-workflows", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = sourceDir.appendingPathComponent("review.md")
        try Data("workflow".utf8).write(to: source)

        let result = try service.installResource(
            kind: .workflow,
            filePath: STPath(source),
            resourceName: nil,
            targetPath: STFolder(targetDir),
            installMethod: .copy
        )

        #expect(result.kind == .workflow)
        #expect(result.resourceName == "review.md")
        #expect(FileManager.default.fileExists(atPath: result.targetPath))
    }

    @Test("uninstall resource removes target")
    func uninstallResourceRemovesTarget() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-resource-uninstall-\(UUID().uuidString)", isDirectory: true)
        let targetDir = root.appendingPathComponent("provider-mcp", isDirectory: true)
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let target = targetDir.appendingPathComponent("cursor-mcp.json")
        try Data("{}".utf8).write(to: target)

        let result = try service.uninstallResource(
            kind: .mcp,
            resourceName: "cursor-mcp.json",
            targetPath: STFolder(targetDir)
        )

        #expect(result.kind == .mcp)
        #expect(result.removed == true)
        #expect(FileManager.default.fileExists(atPath: result.targetPath) == false)
    }

    @Test("scan provider skills reports orphaned copy")
    func scanProviderSkillsReportsOrphaned() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-migrate-scan-\(UUID().uuidString)", isDirectory: true)
        let provider = root.appendingPathComponent("provider", isDirectory: true)
        let global = root.appendingPathComponent("global", isDirectory: true)
        try FileManager.default.createDirectory(at: provider, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: global, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let providerSkill = provider.appendingPathComponent("react-best-practices", isDirectory: true)
        let globalSkill = global.appendingPathComponent("react-best-practices", isDirectory: true)
        try FileManager.default.createDirectory(at: providerSkill, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: globalSkill, withIntermediateDirectories: true)

        let result = try service.scanProviderSkills(providerPath: STFolder(provider), globalSkillsPath: STFolder(global))
        #expect(result.states.contains(where: { $0.skillID == "react-best-practices" && $0.state == .orphaned }))
    }

    @Test("migrate skill links from global to provider")
    func migrateSkillLinksFromGlobal() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-migrate-apply-\(UUID().uuidString)", isDirectory: true)
        let provider = root.appendingPathComponent("provider", isDirectory: true)
        let global = root.appendingPathComponent("global", isDirectory: true)
        try FileManager.default.createDirectory(at: provider, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: global, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let globalSkill = global.appendingPathComponent("react-best-practices", isDirectory: true)
        try FileManager.default.createDirectory(at: globalSkill, withIntermediateDirectories: true)

        let result = try service.migrateSkill(
            skillID: "react-best-practices",
            providerPath: STFolder(provider),
            globalSkillsPath: STFolder(global),
            installMethod: .symlink
        )
        #expect(result.skillID == "react-best-practices")
        #expect(FileManager.default.fileExists(atPath: result.targetPath))
    }
}
