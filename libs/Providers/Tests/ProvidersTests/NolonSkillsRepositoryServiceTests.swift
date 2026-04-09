import Foundation
import STFilePath
import SKProcessRunner
import Testing
@testable import NolonCoreCLIKit

@Suite("NolonLiveSkillsRepositoryService")
struct NolonSkillsRepositoryServiceTests {
    @Test("remote install skill unpacks zip into NOLON_HOME skills before install")
    func remoteInstallSkillUnpacksZipToStableNolonHome() async throws {
        let tempRoot = try makeTempRoot("nolon-remote-skill")
        let nolonHome = tempRoot.folder(".nolon-home")
        let providerPath = tempRoot.folder("provider-skills")
        defer { try? tempRoot.delete() }

        let zipPath = try makeRemoteSkillZip(at: tempRoot, slug: "react-best-practices")
        let envBackup = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("NOLON_HOME", nolonHome.url.path, 1)
        defer {
            if let envBackup {
                setenv("NOLON_HOME", envBackup, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
        }

        let service = ZipRemoteInstallService(downloadFilePath: zipPath.url.path)
        _ = try await service.remoteInstallSkill(
            slug: "react-best-practices",
            version: "1.0.0",
            baseURL: "https://clawhub.ai",
            providerPath: providerPath,
            skillID: nil,
            installMethod: .symlink
        )

        let stagedSkill = nolonHome
            .folder("skills")
            .folder("react-best-practices")
        #expect(stagedSkill.isExists)
        #expect(stagedSkill.file("SKILL.md").isExists)
        #expect(service.lastInstalledSkillPath == stagedSkill.url.path)
    }

    @Test("remote install skill composes download and install steps")
    func remoteInstallSkillComposesDownloadAndInstall() async throws {
        let service = StubRemoteInstallService()
        let result = try await service.remoteInstallSkill(
            slug: "react-best-practices",
            version: "1.0.0",
            baseURL: "https://clawhub.ai",
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
            baseURL: "https://clawhub.ai",
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
    func syncMapsAccessTokenRequired() async throws {
        let service = NolonLiveSkillsRepositoryService()
        let plan = NolonGitImportPlan(
            source: "vercel/agent-skills",
            normalizedGitURL: "https://github.com/vercel/agent-skills.git",
            subpath: nil,
            providerHost: "github.com",
            owner: "vercel",
            repo: "agent-skills",
            localClonePath: STFolder("/tmp").folder("nolon-sync-\(UUID().uuidString)").url
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
        let root = try makeTempRoot("nolon-install")
        let skillRoot = root.folder("skills").folder("react-best-practices")
        let providerRoot = root.folder("provider")
        _ = skillRoot.createIfNotExists()
        _ = providerRoot.createIfNotExists()
        defer { try? root.delete() }

        let result = try service.installSkill(
            skillPath: STPath(skillRoot.url),
            skillID: nil,
            providerPath: providerRoot,
            installMethod: .symlink
        )

        #expect(result.skillID == "react-best-practices")
        #expect(result.installMethod == .symlink)

        let target = STPath(result.targetPath)
        #expect(target.isExists)
        #expect(target.isSymbolicLink)
    }

    @Test("install skill copies into linked global skills root instead of creating nested symlink")
    func installSkillCopiesIntoLinkedGlobalSkillsRoot() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = try makeTempRoot("nolon-install-linked-root")
        defer { try? root.delete() }

        let repositoryRoot = root.folder("repositories").folder("gate").folder("skills")
        let sourceSkill = repositoryRoot.folder("scale")
        _ = sourceSkill.createIfNotExists()
        try sourceSkill.file("SKILL.md").overlay(
            with: """
            ---
            name: scale
            description: scale helper
            ---
            """
        )

        let globalSkillsRoot = root.folder(".nolon").folder("skills")
        _ = globalSkillsRoot.createIfNotExists()

        let providerHome = root.folder("provider-home")
        _ = providerHome.createIfNotExists()
        let providerSkillsPath = providerHome.subpath("skills")
        try providerSkillsPath.createSymbolicLink(to: STPath(globalSkillsRoot.url.path))

        let result = try service.installSkill(
            skillPath: STPath(sourceSkill.url),
            skillID: nil,
            providerPath: STFolder(providerSkillsPath.url),
            installMethod: .symlink
        )

        let installedSkill = globalSkillsRoot.folder("scale")
        #expect(result.installMethod == .copy)
        #expect(installedSkill.isExists)
        #expect(STPath(installedSkill.url).isSymbolicLink == false)
        #expect(installedSkill.file("SKILL.md").isExists)
    }

    @Test("install skill rejects path-like skill id")
    func installSkillRejectsPathLikeSkillID() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = try makeTempRoot("nolon-install-invalid-id")
        let skillRoot = root.folder("skills").folder("react-best-practices")
        let providerRoot = root.folder("provider")
        _ = skillRoot.createIfNotExists()
        _ = providerRoot.createIfNotExists()
        defer { try? root.delete() }

        do {
            _ = try service.installSkill(
                skillPath: STPath(skillRoot.url),
                skillID: "../escape",
                providerPath: providerRoot,
                installMethod: .symlink
            )
            Issue.record("Expected invalid_arguments")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("single path component"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("uninstall skill removes provider target")
    func uninstallSkillRemovesTarget() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = try makeTempRoot("nolon-uninstall")
        let providerRoot = root.folder("provider")
        _ = providerRoot.createIfNotExists()
        defer { try? root.delete() }

        let target = providerRoot.folder("react-best-practices")
        _ = target.createIfNotExists()

        let result = try service.uninstallSkill(skillID: "react-best-practices", providerPath: providerRoot)
        #expect(result.removed == true)
        #expect(STPath(result.targetPath).isExists == false)
    }

    @Test("install resource copies file to target path")
    func installResourceCopiesFile() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = try makeTempRoot("nolon-resource-install")
        let sourceDir = root.folder("source")
        let targetDir = root.folder("provider-workflows")
        _ = sourceDir.createIfNotExists()
        _ = targetDir.createIfNotExists()
        defer { try? root.delete() }

        let source = sourceDir.file("review.md")
        try Data("workflow".utf8).write(to: source.url)

        let result = try service.installResource(
            kind: .workflow,
            filePath: STPath(source.url),
            resourceName: nil,
            targetPath: targetDir,
            installMethod: .copy
        )

        #expect(result.kind == .workflow)
        #expect(result.resourceName == "review.md")
        #expect(STPath(result.targetPath).isExists)
    }

    @Test("install resource rejects path-like resource name")
    func installResourceRejectsPathLikeResourceName() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = try makeTempRoot("nolon-resource-invalid-name")
        let sourceDir = root.folder("source")
        let targetDir = root.folder("provider-workflows")
        _ = sourceDir.createIfNotExists()
        _ = targetDir.createIfNotExists()
        defer { try? root.delete() }

        let source = sourceDir.file("review.md")
        try Data("workflow".utf8).write(to: source.url)

        do {
            _ = try service.installResource(
                kind: .workflow,
                filePath: STPath(source.url),
                resourceName: "../review.md",
                targetPath: targetDir,
                installMethod: .copy
            )
            Issue.record("Expected invalid_arguments")
        } catch let error as NolonCoreCLIError {
            #expect(error.code == "invalid_arguments")
            #expect((error.errorDescription ?? "").contains("single path component"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("uninstall resource removes target")
    func uninstallResourceRemovesTarget() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = try makeTempRoot("nolon-resource-uninstall")
        let targetDir = root.folder("provider-mcp")
        _ = targetDir.createIfNotExists()
        defer { try? root.delete() }

        let target = targetDir.file("cursor-mcp.json")
        try Data("{}".utf8).write(to: target.url)

        let result = try service.uninstallResource(
            kind: .mcp,
            resourceName: "cursor-mcp.json",
            targetPath: targetDir
        )

        #expect(result.kind == .mcp)
        #expect(result.removed == true)
        #expect(STPath(result.targetPath).isExists == false)
    }

    @Test("scan provider skills reports orphaned copy")
    func scanProviderSkillsReportsOrphaned() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = try makeTempRoot("nolon-migrate-scan")
        let provider = root.folder("provider")
        let global = root.folder("global")
        _ = provider.createIfNotExists()
        _ = global.createIfNotExists()
        defer { try? root.delete() }

        let providerSkill = provider.folder("react-best-practices")
        let globalSkill = global.folder("react-best-practices")
        _ = providerSkill.createIfNotExists()
        _ = globalSkill.createIfNotExists()

        let result = try service.scanProviderSkills(providerPath: provider, globalSkillsPath: global)
        #expect(result.states.contains(where: { $0.skillID == "react-best-practices" && $0.state == .orphaned }))
    }

    @Test("migrate skill links from global to provider")
    func migrateSkillLinksFromGlobal() throws {
        let service = NolonLiveSkillsRepositoryService()
        let root = try makeTempRoot("nolon-migrate-apply")
        let provider = root.folder("provider")
        let global = root.folder("global")
        _ = provider.createIfNotExists()
        _ = global.createIfNotExists()
        defer { try? root.delete() }

        let globalSkill = global.folder("react-best-practices")
        _ = globalSkill.createIfNotExists()

        let result = try service.migrateSkill(
            skillID: "react-best-practices",
            providerPath: provider,
            globalSkillsPath: global,
            installMethod: .symlink
        )
        #expect(result.skillID == "react-best-practices")
        #expect(STPath(result.targetPath).isExists)
    }
}

private func makeTempRoot(_ prefix: String) throws -> STFolder {
    let root = STFolder("/tmp").folder("\(prefix)-\(UUID().uuidString)")
    _ = root.createIfNotExists()
    return root
}

private func makeRemoteSkillZip(at root: STFolder, slug: String) throws -> STFile {
    let skillRoot = root.folder("source").folder(slug)
    _ = skillRoot.createIfNotExists()
    try skillRoot.file("SKILL.md").overlay(
        with: """
        ---
        name: \(slug)
        description: test
        ---
        # \(slug)
        """)

    let zipFile = root.file("\(slug).zip")
    var payload = SKProcessPayload.executableURL(URL(fileURLWithPath: "/usr/bin/ditto"))
    payload.arguments = ["-c", "-k", skillRoot.url.path, zipFile.url.path]
    payload.throwOnNonZeroExit = true
    _ = try SKProcessRunner.runSync(payload)
    return zipFile
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
