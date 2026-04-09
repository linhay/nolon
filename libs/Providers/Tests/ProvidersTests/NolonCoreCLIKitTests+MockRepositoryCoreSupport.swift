import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

func makeExecutableScript(at path: String) throws {
let url = URL(fileURLWithPath: path)
try "#!/bin/sh\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
}

func makeMockRemoteSkillFolder(slug: String) throws -> URL {
let root = try STFolder(sanbox: .temporary).folder("nolon-core-cli-tests-\(UUID().uuidString)").create()
let folder = try root.create(folder: slug)
try """
---
name: \(slug)
description: test
---
# \(slug)
""".write(to: folder.file("SKILL.md").url, atomically: true, encoding: .utf8)
return folder.url
}

func canonicalJSON(_ raw: String) throws -> String {
let data = Data(raw.utf8)
let object = try JSONSerialization.jsonObject(with: data)
let normalized = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
guard let string = String(data: normalized, encoding: .utf8) else {
    throw NolonCoreCLIError.domainFailed(code: "json_encoding_failed", message: "Failed to encode canonical JSON")
}
return string
}

protocol DelegatingMockSkillsRepositoryService: NolonSkillsRepositoryServing {
var base: MockSkillsRepositoryService { get }
}

extension DelegatingMockSkillsRepositoryService {
func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
    try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
}

func preflightGitSync(
    source: String,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) throws -> NolonGitSyncPreflight {
    try base.preflightGitSync(
        source: source,
        accessToken: accessToken,
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy
    )
}

func syncGitRepository(
    plan: NolonGitImportPlan,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) async throws -> NolonGitSyncResult {
    try await base.syncGitRepository(
        plan: plan,
        accessToken: accessToken,
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy
    )
}

func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
    base.repositoryResources.skillsDirectories
}

func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
    base.localRepositories
}

func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
    base.parseSkillMetadata(content: content, directoryName: directoryName)
}

func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
    base.repositoryResources
}

func installSkill(
    skillPath: STPath,
    skillID: String?,
    providerPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    try base.installSkill(
        skillPath: skillPath,
        skillID: skillID,
        providerPath: providerPath,
        installMethod: installMethod
    )
}

func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
    try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
}

func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
    try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
}

func migrateSkill(
    skillID: String,
    providerPath: STFolder,
    globalSkillsPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    try base.migrateSkill(
        skillID: skillID,
        providerPath: providerPath,
        globalSkillsPath: globalSkillsPath,
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
    try base.installResource(
        kind: kind,
        filePath: filePath,
        resourceName: resourceName,
        targetPath: targetPath,
        installMethod: installMethod
    )
}

func uninstallResource(
    kind: NolonResourceKind,
    resourceName: String,
    targetPath: STFolder
) throws -> NolonResourceUninstallResult {
    try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
}

func listMcpServers(provider: String) throws -> NolonMcpServerListResult {
    try base.listMcpServers(provider: provider)
}

func setMcpServerEnabled(provider: String, name: String, enabled: Bool) throws -> NolonMcpServerMutationResult {
    try base.setMcpServerEnabled(provider: provider, name: name, enabled: enabled)
}

func upsertMcpServer(
    provider: String,
    name: String,
    url: String?,
    command: String?,
    args: [String],
    env: [String: String],
    enabled: Bool?
) throws -> NolonMcpServerMutationResult {
    try base.upsertMcpServer(
        provider: provider,
        name: name,
        url: url,
        command: command,
        args: args,
        env: env,
        enabled: enabled
    )
}

func removeMcpServer(provider: String, name: String) throws -> NolonMcpServerMutationResult {
    try base.removeMcpServer(provider: provider, name: name)
}

func migrateMcpServersToCache(provider: String, overwrite: Bool) throws -> NolonMcpCacheMigrateResult {
    try base.migrateMcpServersToCache(provider: provider, overwrite: overwrite)
}

func mcpCacheStatus(provider: String, name: String?) throws -> NolonMcpCacheStatusResult {
    try base.mcpCacheStatus(provider: provider, name: name)
}

func listRemoteResources(
    kind: NolonRemoteCatalogKind,
    query: String?,
    limit: Int,
    baseURL: String
) async throws -> NolonRemoteListResult {
    try await base.listRemoteResources(kind: kind, query: query, limit: limit, baseURL: baseURL)
}

func downloadRemoteResource(
    kind: NolonRemoteCatalogKind,
    slug: String,
    version: String?,
    baseURL: String
) async throws -> NolonRemoteDownloadResult {
    try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
}
}

struct SyncErrorMockSkillsRepositoryService: NolonSkillsRepositoryServing {
func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
    NolonGitImportPlan(
        source: source,
        normalizedGitURL: "https://github.com/vercel/agent-skills.git",
        subpath: nil,
        providerHost: "github.com",
        owner: "vercel",
        repo: "agent-skills",
        localClonePath: repositoriesRoot.folder("github.com/vercel@agent-skills").url
    )
}

func preflightGitSync(
    source: String,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) throws -> NolonGitSyncPreflight {
    NolonGitSyncPreflight(
        isValidURL: true,
        normalizedGitURL: "https://github.com/vercel/agent-skills.git",
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy,
        credentialMode: "https_anonymous",
        requiresAccessToken: false,
        warnings: [],
        issues: []
    )
}

func syncGitRepository(
    plan: NolonGitImportPlan,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) async throws -> NolonGitSyncResult {
    throw NolonCoreCLIError.syncFailed(
        code: "access_token_required",
        message: "access token is required for token-only strategy",
        detail: NolonGitSyncErrorDetail(
            gitURL: "https://github.com/vercel/agent-skills.git",
            pullStrategy: .ffOnly,
            credentialStrategy: .tokenOnly,
            hasAccessToken: false
        )
    )
}

func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] { [] }
func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
    NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
}
func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? { nil }

func installSkill(
    skillPath: STPath,
    skillID: String?,
    providerPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    NolonSkillInstallResult(
        skillID: skillID ?? "react-best-practices",
        sourcePath: skillPath.url.path,
        targetPath: providerPath.subpath(skillID ?? "react-best-practices").url.path,
        installMethod: installMethod
    )
}

func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
    NolonSkillUninstallResult(
        skillID: skillID,
        targetPath: providerPath.subpath(skillID).url.path,
        removed: true
    )
}

func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
    NolonSkillMigrateScanResult(
        providerPath: providerPath.url.path,
        globalSkillsPath: globalSkillsPath.url.path,
        states: [NolonProviderSkillState(skillID: "react-best-practices", path: providerPath.subpath("react-best-practices").url.path, state: .orphaned)]
    )
}

func migrateSkill(
    skillID: String,
    providerPath: STFolder,
    globalSkillsPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    NolonSkillInstallResult(
        skillID: skillID,
        sourcePath: globalSkillsPath.subpath(skillID).url.path,
        targetPath: providerPath.subpath(skillID).url.path,
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

func uninstallResource(
    kind: NolonResourceKind,
    resourceName: String,
    targetPath: STFolder
) throws -> NolonResourceUninstallResult {
    NolonResourceUninstallResult(
        kind: kind,
        resourceName: resourceName,
        targetPath: targetPath.subpath(resourceName).url.path,
        removed: true
    )
}

func listMcpServers(provider: String) throws -> NolonMcpServerListResult {
    NolonMcpServerListResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        items: [
            NolonMcpServerItem(
                name: "playwright",
                url: nil,
                command: "npx",
                args: ["@playwright/mcp@latest"],
                env: ["PLAYWRIGHT_HEADLESS": "1"],
                enabled: true
            ),
        ]
    )
}

func setMcpServerEnabled(provider: String, name: String, enabled: Bool) throws -> NolonMcpServerMutationResult {
    NolonMcpServerMutationResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        name: name,
        action: enabled ? "enabled" : "disabled"
    )
}

func upsertMcpServer(
    provider: String,
    name: String,
    url: String?,
    command: String?,
    args: [String],
    env: [String: String],
    enabled: Bool?
) throws -> NolonMcpServerMutationResult {
    _ = url
    _ = command
    _ = args
    _ = env
    _ = enabled
    return NolonMcpServerMutationResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        name: name,
        action: "upserted"
    )
}

func removeMcpServer(provider: String, name: String) throws -> NolonMcpServerMutationResult {
    NolonMcpServerMutationResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        name: name,
        action: "removed"
    )
}

func migrateMcpServersToCache(provider: String, overwrite: Bool) throws -> NolonMcpCacheMigrateResult {
    _ = overwrite
    return NolonMcpCacheMigrateResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        migrated: 1,
        skipped: 0,
        updated: 0
    )
}

func mcpCacheStatus(provider: String, name: String?) throws -> NolonMcpCacheStatusResult {
    let allItems = [
        NolonMcpCacheStatusItem(
            name: "playwright",
            state: .migratedUpToDate,
            cachePath: "/tmp/.nolon/mcps/playwright.json"
        ),
    ]
    let items: [NolonMcpCacheStatusItem]
    if let name {
        items = allItems.filter { $0.name == name }
    } else {
        items = allItems
    }
    return NolonMcpCacheStatusResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        items: items
    )
}

func listRemoteResources(
    kind: NolonRemoteCatalogKind,
    query: String?,
    limit: Int,
    baseURL: String
) async throws -> NolonRemoteListResult {
    NolonRemoteListResult(
        kind: kind,
        baseURL: baseURL,
        query: query,
        limit: limit,
        items: [
            NolonRemoteCatalogItem(
                kind: kind,
                slug: "react-best-practices",
                displayName: "React Best Practices",
                summary: "desc",
                latestVersion: "1.0.0",
                updatedAt: nil,
                downloads: nil,
                stars: nil,
                installs: nil
            )
        ]
    )
}

func downloadRemoteResource(
    kind: NolonRemoteCatalogKind,
    slug: String,
    version: String?,
    baseURL: String
) async throws -> NolonRemoteDownloadResult {
    if kind == .skill {
        let folder = try makeMockRemoteSkillFolder(slug: slug)
        return NolonRemoteDownloadResult(
            kind: kind,
            slug: slug,
            version: version,
            baseURL: baseURL,
            filePath: folder.path
        )
    }
    return NolonRemoteDownloadResult(
        kind: kind,
        slug: slug,
        version: version,
        baseURL: baseURL,
        filePath: "/tmp/\(slug).bin"
    )
}
}

struct GitRefConflictSyncMockSkillsRepositoryService: NolonSkillsRepositoryServing {
func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
    NolonGitImportPlan(
        source: source,
        normalizedGitURL: "https://github.com/linhay/STFilePath.git",
        subpath: nil,
        providerHost: "github.com",
        owner: "linhay",
        repo: "STFilePath",
        localClonePath: repositoriesRoot.folder("github.com/linhay@STFilePath").url
    )
}

func preflightGitSync(
    source: String,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) throws -> NolonGitSyncPreflight {
    NolonGitSyncPreflight(
        isValidURL: true,
        normalizedGitURL: "https://github.com/linhay/STFilePath.git",
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy,
        credentialMode: "https_anonymous",
        requiresAccessToken: false,
        warnings: [],
        issues: []
    )
}

func syncGitRepository(
    plan: NolonGitImportPlan,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) async throws -> NolonGitSyncResult {
    throw NolonCoreCLIError.syncFailed(
        code: "git_pull_failed",
        message: "Failed to update repository: error: cannot lock ref 'refs/remotes/origin/main': is at aaa but expected bbb\nFrom github.com:linhay/STFilePath\n ! bbb..aaa  main -> origin/main  (unable to update local ref)",
        detail: NolonGitSyncErrorDetail(
            gitURL: "https://github.com/linhay/STFilePath.git",
            pullStrategy: .ffOnly,
            credentialStrategy: .automatic,
            hasAccessToken: false
        )
    )
}

func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] { [] }
func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
    NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
}
func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? { nil }

func installSkill(
    skillPath: STPath,
    skillID: String?,
    providerPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    NolonSkillInstallResult(
        skillID: skillID ?? "react-best-practices",
        sourcePath: skillPath.url.path,
        targetPath: providerPath.subpath(skillID ?? "react-best-practices").url.path,
        installMethod: installMethod
    )
}

func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
    NolonSkillUninstallResult(
        skillID: skillID,
        targetPath: providerPath.subpath(skillID).url.path,
        removed: true
    )
}

func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
    NolonSkillMigrateScanResult(providerPath: providerPath.url.path, globalSkillsPath: globalSkillsPath.url.path, states: [])
}

func migrateSkill(
    skillID: String,
    providerPath: STFolder,
    globalSkillsPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    NolonSkillInstallResult(
        skillID: skillID,
        sourcePath: globalSkillsPath.subpath(skillID).url.path,
        targetPath: providerPath.subpath(skillID).url.path,
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
    let resolvedName = resourceName ?? filePath.url.lastPathComponent
    return NolonResourceInstallResult(
        kind: kind,
        resourceName: resolvedName,
        sourcePath: filePath.url.path,
        targetPath: targetPath.subpath(resolvedName).url.path,
        installMethod: installMethod
    )
}

func uninstallResource(
    kind: NolonResourceKind,
    resourceName: String,
    targetPath: STFolder
) throws -> NolonResourceUninstallResult {
    NolonResourceUninstallResult(kind: kind, resourceName: resourceName, targetPath: targetPath.subpath(resourceName).url.path, removed: true)
}

func listRemoteResources(
    kind: NolonRemoteCatalogKind,
    query: String?,
    limit: Int,
    baseURL: String
) async throws -> NolonRemoteListResult {
    NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [])
}

func downloadRemoteResource(
    kind: NolonRemoteCatalogKind,
    slug: String,
    version: String?,
    baseURL: String
) async throws -> NolonRemoteDownloadResult {
    NolonRemoteDownloadResult(
        kind: kind,
        slug: slug,
        version: version ?? "latest",
        baseURL: baseURL,
        filePath: "/tmp/\(slug).zip"
    )
}

func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] { [] }
}

struct GitPullFastForwardFailedMockSkillsRepositoryService: NolonSkillsRepositoryServing {
private let base = MockSkillsRepositoryService(
    repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
    localRepositories: []
)

func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
    try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
}

func preflightGitSync(
    source: String,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) throws -> NolonGitSyncPreflight {
    try base.preflightGitSync(
        source: source,
        accessToken: accessToken,
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy
    )
}

func syncGitRepository(
    plan: NolonGitImportPlan,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) async throws -> NolonGitSyncResult {
    throw NolonCoreCLIError.syncFailed(
        code: "git_pull_failed",
        message: "Failed to update repository: fatal: Cannot fast-forward to multiple branches.",
        detail: NolonGitSyncErrorDetail(
            gitURL: "https://github.com/linhay/STFilePath.git",
            pullStrategy: .ffOnly,
            credentialStrategy: .automatic,
            hasAccessToken: false
        )
    )
}

func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
    base.discoverSkillsDirectories(at: repositoryPath, maxDepth: maxDepth)
}

func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
    base.listLocalRepositories(repositoriesRoot: repositoriesRoot, maxDepth: maxDepth)
}

func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
    base.parseSkillMetadata(content: content, directoryName: directoryName)
}

func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
    base.discoverRepositoryResources(at: repositoryPath, maxDepth: maxDepth)
}

func installSkill(
    skillPath: STPath,
    skillID: String?,
    providerPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    try base.installSkill(skillPath: skillPath, skillID: skillID, providerPath: providerPath, installMethod: installMethod)
}

func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
    try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
}

func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
    try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
}

func migrateSkill(
    skillID: String,
    providerPath: STFolder,
    globalSkillsPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    try base.migrateSkill(
        skillID: skillID,
        providerPath: providerPath,
        globalSkillsPath: globalSkillsPath,
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
    try base.installResource(
        kind: kind,
        filePath: filePath,
        resourceName: resourceName,
        targetPath: targetPath,
        installMethod: installMethod
    )
}

func uninstallResource(
    kind: NolonResourceKind,
    resourceName: String,
    targetPath: STFolder
) throws -> NolonResourceUninstallResult {
    try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
}

func listRemoteResources(
    kind: NolonRemoteCatalogKind,
    query: String?,
    limit: Int,
    baseURL: String
) async throws -> NolonRemoteListResult {
    try await base.listRemoteResources(kind: kind, query: query, limit: limit, baseURL: baseURL)
}

func downloadRemoteResource(
    kind: NolonRemoteCatalogKind,
    slug: String,
    version: String?,
    baseURL: String
) async throws -> NolonRemoteDownloadResult {
    try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
}
}

struct MockSkillsRepositoryService: NolonSkillsRepositoryServing {
let repositoryResources: NolonRepositoryResources
let localRepositories: [NolonLocalRepositorySummary]

init(
    repositoryResources: NolonRepositoryResources? = nil,
    localRepositories: [NolonLocalRepositorySummary]? = nil
) {
    self.repositoryResources = repositoryResources ?? NolonRepositoryResources(
        skillsDirectories: [NolonSkillsDirectoryCandidate(path: "skills", skillCount: 1, skillNames: ["agent-browser"])],
        workflows: [
            NolonResourceFile(path: "workflows/review.md", kind: "workflow"),
            NolonResourceFile(path: "prompts/review.md", kind: "workflow"),
        ],
        mcps: [NolonResourceFile(path: "mcp_settings.json", kind: "mcp")]
    )
    self.localRepositories = localRepositories ?? [
        NolonLocalRepositorySummary(
            name: "vercel@agent-skills",
            path: "/tmp/repos/github.com/vercel@agent-skills",
            skillsDirectoryCount: 1,
            workflowCount: 2,
            mcpCount: 1
        ),
    ]
}

func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
    NolonGitImportPlan(
        source: source,
        normalizedGitURL: "https://github.com/vercel/agent-skills.git",
        subpath: nil,
        providerHost: "github.com",
        owner: "vercel",
        repo: "agent-skills",
        localClonePath: repositoriesRoot.folder("github.com/vercel@agent-skills").url
    )
}

func preflightGitSync(
    source: String,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) throws -> NolonGitSyncPreflight {
    NolonGitSyncPreflight(
        isValidURL: true,
        normalizedGitURL: "https://github.com/vercel/agent-skills.git",
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy,
        credentialMode: "https_anonymous",
        requiresAccessToken: credentialStrategy == .tokenOnly && (accessToken?.isEmpty != false),
        warnings: credentialStrategy == .tokenOnly ? ["access token is required for token-only strategy"] : [],
        issues: credentialStrategy == .tokenOnly
            ? [NolonGitSyncPreflightIssue(
                code: .accessTokenRequired,
                severity: .error,
                message: "access token is required for token-only strategy"
            )]
            : []
    )
}

func syncGitRepository(
    plan: NolonGitImportPlan,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) async throws -> NolonGitSyncResult {
    #expect(pullStrategy == .ffOnly || pullStrategy == .rebase)
    #expect(credentialStrategy == .automatic || credentialStrategy == .tokenOnly)
    return NolonGitSyncResult(
        mode: "cloned",
        updatedAt: Date(timeIntervalSince1970: 1),
        directories: [],
        defaultBranch: "main",
        credentialMode: "https_token"
    )
}

func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
    repositoryResources.skillsDirectories
}

func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
    localRepositories
}

func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
    NolonSkillStandardMetadata(
        name: directoryName ?? "agent-browser",
        description: "Browser automation skill.",
        license: nil,
        compatibility: nil,
        metadata: ["author": "openai"],
        argumentHint: nil,
        allowedTools: [],
        isValid: true,
        warnings: [],
        issues: []
    )
}

func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
    repositoryResources
}

func installSkill(
    skillPath: STPath,
    skillID: String?,
    providerPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    NolonSkillInstallResult(
        skillID: skillID ?? skillPath.url.lastPathComponent,
        sourcePath: skillPath.url.path,
        targetPath: providerPath.subpath(skillID ?? skillPath.url.lastPathComponent).url.path,
        installMethod: installMethod
    )
}

func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
    NolonSkillUninstallResult(
        skillID: skillID,
        targetPath: providerPath.subpath(skillID).url.path,
        removed: true
    )
}

func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
    NolonSkillMigrateScanResult(
        providerPath: providerPath.url.path,
        globalSkillsPath: globalSkillsPath.url.path,
        states: [NolonProviderSkillState(skillID: "react-best-practices", path: providerPath.subpath("react-best-practices").url.path, state: .orphaned)]
    )
}

func migrateSkill(
    skillID: String,
    providerPath: STFolder,
    globalSkillsPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    NolonSkillInstallResult(
        skillID: skillID,
        sourcePath: globalSkillsPath.subpath(skillID).url.path,
        targetPath: providerPath.subpath(skillID).url.path,
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

func uninstallResource(
    kind: NolonResourceKind,
    resourceName: String,
    targetPath: STFolder
) throws -> NolonResourceUninstallResult {
    NolonResourceUninstallResult(
        kind: kind,
        resourceName: resourceName,
        targetPath: targetPath.subpath(resourceName).url.path,
        removed: true
    )
}

func listMcpServers(provider: String) throws -> NolonMcpServerListResult {
    NolonMcpServerListResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        items: [
            NolonMcpServerItem(
                name: "playwright",
                url: nil,
                command: "npx",
                args: ["@playwright/mcp@latest"],
                env: ["PLAYWRIGHT_HEADLESS": "1"],
                enabled: true
            ),
        ]
    )
}

func setMcpServerEnabled(provider: String, name: String, enabled: Bool) throws -> NolonMcpServerMutationResult {
    NolonMcpServerMutationResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        name: name,
        action: enabled ? "enabled" : "disabled"
    )
}

func upsertMcpServer(
    provider: String,
    name: String,
    url: String?,
    command: String?,
    args: [String],
    env: [String: String],
    enabled: Bool?
) throws -> NolonMcpServerMutationResult {
    _ = url
    _ = command
    _ = args
    _ = env
    _ = enabled
    return NolonMcpServerMutationResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        name: name,
        action: "upserted"
    )
}

func removeMcpServer(provider: String, name: String) throws -> NolonMcpServerMutationResult {
    NolonMcpServerMutationResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        name: name,
        action: "removed"
    )
}

func migrateMcpServersToCache(provider: String, overwrite: Bool) throws -> NolonMcpCacheMigrateResult {
    _ = overwrite
    return NolonMcpCacheMigrateResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        migrated: 1,
        skipped: 0,
        updated: 0
    )
}

func mcpCacheStatus(provider: String, name: String?) throws -> NolonMcpCacheStatusResult {
    let allItems = [
        NolonMcpCacheStatusItem(
            name: "playwright",
            state: .migratedUpToDate,
            cachePath: "/tmp/.nolon/mcps/playwright.json"
        ),
    ]
    let items: [NolonMcpCacheStatusItem]
    if let name {
        items = allItems.filter { $0.name == name }
    } else {
        items = allItems
    }
    return NolonMcpCacheStatusResult(
        providerID: provider,
        configPath: "/tmp/\(provider)/mcp_settings.json",
        items: items
    )
}

func listRemoteResources(
    kind: NolonRemoteCatalogKind,
    query: String?,
    limit: Int,
    baseURL: String
) async throws -> NolonRemoteListResult {
    NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [])
}

func downloadRemoteResource(
    kind: NolonRemoteCatalogKind,
    slug: String,
    version: String?,
    baseURL: String
) async throws -> NolonRemoteDownloadResult {
    if kind == .skill {
        let folder = try makeMockRemoteSkillFolder(slug: slug)
        return NolonRemoteDownloadResult(
            kind: kind,
            slug: slug,
            version: version,
            baseURL: baseURL,
            filePath: folder.path
        )
    }
    return NolonRemoteDownloadResult(kind: kind, slug: slug, version: version, baseURL: baseURL, filePath: "/tmp/\(slug).bin")
}
}

struct RemoteFallbackMockSkillsRepositoryService: NolonSkillsRepositoryServing {
private let base = MockSkillsRepositoryService(
    repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
    localRepositories: []
)

func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
    try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
}
func preflightGitSync(
    source: String,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) throws -> NolonGitSyncPreflight {
    try base.preflightGitSync(
        source: source,
        accessToken: accessToken,
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy
    )
}
func syncGitRepository(
    plan: NolonGitImportPlan,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) async throws -> NolonGitSyncResult {
    try await base.syncGitRepository(
        plan: plan,
        accessToken: accessToken,
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy
    )
}
func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
    base.discoverSkillsDirectories(at: repositoryPath, maxDepth: maxDepth)
}
func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
    []
}
func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
    base.parseSkillMetadata(content: content, directoryName: directoryName)
}
func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
    NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
}
func installSkill(
    skillPath: STPath,
    skillID: String?,
    providerPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    try base.installSkill(
        skillPath: skillPath,
        skillID: skillID,
        providerPath: providerPath,
        installMethod: installMethod
    )
}
func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
    try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
}
func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
    try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
}
func migrateSkill(
    skillID: String,
    providerPath: STFolder,
    globalSkillsPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    try base.migrateSkill(
        skillID: skillID,
        providerPath: providerPath,
        globalSkillsPath: globalSkillsPath,
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
    try base.installResource(
        kind: kind,
        filePath: filePath,
        resourceName: resourceName,
        targetPath: targetPath,
        installMethod: installMethod
    )
}
func uninstallResource(
    kind: NolonResourceKind,
    resourceName: String,
    targetPath: STFolder
) throws -> NolonResourceUninstallResult {
    try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
}
func listRemoteResources(
    kind: NolonRemoteCatalogKind,
    query: String?,
    limit: Int,
    baseURL: String
) async throws -> NolonRemoteListResult {
    let item = NolonRemoteCatalogItem(
        kind: .skill,
        slug: "xcode",
        displayName: "Xcode",
        summary: "Xcode skill",
        latestVersion: "1.0.0",
        updatedAt: Date(timeIntervalSince1970: 0),
        downloads: nil,
        stars: nil,
        installs: nil
    )
    return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [item])
}
func downloadRemoteResource(
    kind: NolonRemoteCatalogKind,
    slug: String,
    version: String?,
    baseURL: String
) async throws -> NolonRemoteDownloadResult {
    try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
}
}

struct EmptySkillLookupMockSkillsRepositoryService: NolonSkillsRepositoryServing {
private let base = MockSkillsRepositoryService(
    repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
    localRepositories: []
)

func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
    try base.planGitImport(source: source, repositoriesRoot: repositoriesRoot)
}
func preflightGitSync(
    source: String,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) throws -> NolonGitSyncPreflight {
    try base.preflightGitSync(
        source: source,
        accessToken: accessToken,
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy
    )
}
func syncGitRepository(
    plan: NolonGitImportPlan,
    accessToken: String?,
    pullStrategy: NolonGitPullStrategy,
    credentialStrategy: NolonGitCredentialStrategy
) async throws -> NolonGitSyncResult {
    try await base.syncGitRepository(
        plan: plan,
        accessToken: accessToken,
        pullStrategy: pullStrategy,
        credentialStrategy: credentialStrategy
    )
}
func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
    []
}
func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
    []
}
func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
    base.parseSkillMetadata(content: content, directoryName: directoryName)
}
func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
    NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: [])
}
func installSkill(
    skillPath: STPath,
    skillID: String?,
    providerPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    try base.installSkill(
        skillPath: skillPath,
        skillID: skillID,
        providerPath: providerPath,
        installMethod: installMethod
    )
}
func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
    try base.uninstallSkill(skillID: skillID, providerPath: providerPath)
}
func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
    try base.scanProviderSkills(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
}
func migrateSkill(
    skillID: String,
    providerPath: STFolder,
    globalSkillsPath: STFolder,
    installMethod: NolonSkillInstallMethod
) throws -> NolonSkillInstallResult {
    try base.migrateSkill(
        skillID: skillID,
        providerPath: providerPath,
        globalSkillsPath: globalSkillsPath,
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
    try base.installResource(
        kind: kind,
        filePath: filePath,
        resourceName: resourceName,
        targetPath: targetPath,
        installMethod: installMethod
    )
}
func uninstallResource(
    kind: NolonResourceKind,
    resourceName: String,
    targetPath: STFolder
) throws -> NolonResourceUninstallResult {
    try base.uninstallResource(kind: kind, resourceName: resourceName, targetPath: targetPath)
}
func listRemoteResources(
    kind: NolonRemoteCatalogKind,
    query: String?,
    limit: Int,
    baseURL: String
) async throws -> NolonRemoteListResult {
    NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [])
}
func downloadRemoteResource(
    kind: NolonRemoteCatalogKind,
    slug: String,
    version: String?,
    baseURL: String
) async throws -> NolonRemoteDownloadResult {
    try await base.downloadRemoteResource(kind: kind, slug: slug, version: version, baseURL: baseURL)
}
}
