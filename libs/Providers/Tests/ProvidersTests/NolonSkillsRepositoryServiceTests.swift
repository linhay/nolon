import Foundation
import STFilePath
import Testing
@testable import NolonCoreCLIKit

@Suite("NolonLiveSkillsRepositoryService")
struct NolonSkillsRepositoryServiceTests {
    @Test("remote install skill unpacks zip into NOLON_HOME skills before install")
    func remoteInstallSkillUnpacksZipToStableNolonHome() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-remote-skill-\(UUID().uuidString)", isDirectory: true)
        let nolonHome = tempRoot.appendingPathComponent(".nolon-home", isDirectory: true)
        let providerPath = STFolder(tempRoot.appendingPathComponent("provider-skills", isDirectory: true))
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let zipPath = try makeRemoteSkillZip(at: tempRoot, slug: "react-best-practices")
        let envBackup = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("NOLON_HOME", nolonHome.path, 1)
        defer {
            if let envBackup {
                setenv("NOLON_HOME", envBackup, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
        }

        let service = ZipRemoteInstallService(downloadFilePath: zipPath.path)
        _ = try await service.remoteInstallSkill(
            slug: "react-best-practices",
            version: "1.0.0",
            baseURL: "https://clawdhub.com",
            providerPath: providerPath,
            skillID: nil,
            installMethod: .symlink
        )

        let stagedSkillPath = nolonHome
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent("react-best-practices", isDirectory: true)
            .path
        let skillManifestPath = URL(fileURLWithPath: stagedSkillPath).appendingPathComponent("SKILL.md").path
        #expect(FileManager.default.fileExists(atPath: stagedSkillPath))
        #expect(FileManager.default.fileExists(atPath: skillManifestPath))
        #expect(service.lastInstalledSkillPath == stagedSkillPath)
    }

    @Test("remote install skill composes download and install steps")
    func remoteInstallSkillComposesDownloadAndInstall() async throws {
        let service = StubRemoteInstallService()
        let result = try await service.remoteInstallSkill(
            slug: "react-best-practices",
            version: "1.0.0",
            baseURL: "https://clawdhub.com",
            providerPath: STFolder("/tmp/provider-skills"),
            skillID: nil,
            installMethod: .copy
        )

        #expect(result.kind == .skill)
        #expect(result.slug == "react-best-practices")
        #expect(result.downloadedFilePath.contains("react-best-practices"))
        #expect(result.installedPath == "/tmp/provider-skills/react-best-practices")
        #expect(result.skillID == "react-best-practices")
        #expect(result.resourceName == nil)
    }

    @Test("remote install resource composes download and install steps")
    func remoteInstallResourceComposesDownloadAndInstall() async throws {
        let service = StubRemoteInstallService()
        let result = try await service.remoteInstallResource(
            kind: .workflow,
            slug: "review-agent",
            version: nil,
            baseURL: "https://clawdhub.com",
            targetPath: STFolder("/tmp/provider-workflows"),
            resourceName: "review.md",
            installMethod: .symlink
        )

        #expect(result.kind == .workflow)
        #expect(result.slug == "review-agent")
        #expect(result.downloadedFilePath == "/tmp/downloads/review-agent.workflow.zip")
        #expect(result.installedPath == "/tmp/provider-workflows/review.md")
        #expect(result.skillID == nil)
        #expect(result.resourceName == "review.md")
    }

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

private func makeRemoteSkillZip(at root: URL, slug: String) throws -> URL {
    let skillRoot = root
        .appendingPathComponent("source", isDirectory: true)
        .appendingPathComponent(slug, isDirectory: true)
    try FileManager.default.createDirectory(at: skillRoot, withIntermediateDirectories: true)
    let skillMD = skillRoot.appendingPathComponent("SKILL.md")
    try """
    ---
    name: \(slug)
    description: test
    ---
    # \(slug)
    """.write(to: skillMD, atomically: true, encoding: .utf8)

    let zipURL = root.appendingPathComponent("\(slug).zip")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-c", "-k", skillRoot.path, zipURL.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "NolonSkillsRepositoryServiceTests", code: Int(process.terminationStatus))
    }
    return zipURL
}

private final class ZipRemoteInstallService: @unchecked Sendable, NolonSkillsRepositoryServing {
    let downloadFilePath: String
    var lastInstalledSkillPath: String?

    init(downloadFilePath: String) {
        self.downloadFilePath = downloadFilePath
    }

    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan { fatalError("unused") }
    func preflightGitSync(source: String, accessToken: String?, pullStrategy: NolonGitPullStrategy, credentialStrategy: NolonGitCredentialStrategy) throws -> NolonGitSyncPreflight { fatalError("unused") }
    func syncGitRepository(plan: NolonGitImportPlan, accessToken: String?, pullStrategy: NolonGitPullStrategy, credentialStrategy: NolonGitCredentialStrategy) async throws -> NolonGitSyncResult { fatalError("unused") }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] { [] }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources { .init(skillsDirectories: [], workflows: [], mcps: []) }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? { nil }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult { fatalError("unused") }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult { fatalError("unused") }
    func migrateSkill(skillID: String, providerPath: STFolder, globalSkillsPath: STFolder, installMethod: NolonSkillInstallMethod) throws -> NolonSkillInstallResult { fatalError("unused") }
    func installResource(kind: NolonResourceKind, filePath: STPath, resourceName: String?, targetPath: STFolder, installMethod: NolonSkillInstallMethod) throws -> NolonResourceInstallResult { fatalError("unused") }
    func uninstallResource(kind: NolonResourceKind, resourceName: String, targetPath: STFolder) throws -> NolonResourceUninstallResult { fatalError("unused") }
    func listRemoteResources(kind: NolonRemoteCatalogKind, query: String?, limit: Int, baseURL: String) async throws -> NolonRemoteListResult { fatalError("unused") }

    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        NolonRemoteDownloadResult(kind: kind, slug: slug, version: version, baseURL: baseURL, filePath: downloadFilePath)
    }

    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        lastInstalledSkillPath = skillPath.url.path
        return NolonSkillInstallResult(
            skillID: skillID ?? "react-best-practices",
            sourcePath: skillPath.url.path,
            targetPath: providerPath.subpath(skillID ?? "react-best-practices").url.path,
            installMethod: installMethod
        )
    }
}

private struct StubRemoteInstallService: NolonSkillsRepositoryServing {
    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan { fatalError("unused") }
    func preflightGitSync(source: String, accessToken: String?, pullStrategy: NolonGitPullStrategy, credentialStrategy: NolonGitCredentialStrategy) throws -> NolonGitSyncPreflight { fatalError("unused") }
    func syncGitRepository(plan: NolonGitImportPlan, accessToken: String?, pullStrategy: NolonGitPullStrategy, credentialStrategy: NolonGitCredentialStrategy) async throws -> NolonGitSyncResult { fatalError("unused") }
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] { [] }
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources { .init(skillsDirectories: [], workflows: [], mcps: []) }
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? { nil }
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult { fatalError("unused") }
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult { fatalError("unused") }
    func migrateSkill(skillID: String, providerPath: STFolder, globalSkillsPath: STFolder, installMethod: NolonSkillInstallMethod) throws -> NolonSkillInstallResult { fatalError("unused") }
    func uninstallResource(kind: NolonResourceKind, resourceName: String, targetPath: STFolder) throws -> NolonResourceUninstallResult { fatalError("unused") }
    func listRemoteResources(kind: NolonRemoteCatalogKind, query: String?, limit: Int, baseURL: String) async throws -> NolonRemoteListResult { fatalError("unused") }

    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        if kind == .skill {
            let root = try STFolder(sanbox: .temporary).folder("nolon-svc-test-\(UUID().uuidString)").create()
            let folder = try root.create(folder: slug)
            try """
            ---
            name: \(slug)
            description: stub
            ---
            # \(slug)
            """.write(to: folder.file("SKILL.md").url, atomically: true, encoding: .utf8)
            return NolonRemoteDownloadResult(
                kind: kind,
                slug: slug,
                version: version,
                baseURL: baseURL,
                filePath: folder.url.path
            )
        }
        return NolonRemoteDownloadResult(
            kind: kind,
            slug: slug,
            version: version,
            baseURL: baseURL,
            filePath: "/tmp/downloads/\(slug).\(kind.rawValue).zip"
        )
    }

    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        let resolved = skillID ?? skillPath.url.deletingPathExtension().lastPathComponent
        return NolonSkillInstallResult(
            skillID: resolved,
            sourcePath: skillPath.url.path,
            targetPath: providerPath.subpath(resolved).url.path,
            installMethod: installMethod
        )
    }

    func installResource(
        kind: NolonResourceKind,
        filePath: STPath,
        resourceName: String?,
        targetPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonResourceInstallResult {
        let resolved = resourceName ?? filePath.url.lastPathComponent
        return NolonResourceInstallResult(
            kind: kind,
            resourceName: resolved,
            sourcePath: filePath.url.path,
            targetPath: targetPath.subpath(resolved).url.path,
            installMethod: installMethod
        )
    }
}
