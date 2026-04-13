import Foundation
import ArgumentParser
import STFilePath
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage

private func makeRemoteSearchBaseService() -> MockSkillsRepositoryService {
    MockSkillsRepositoryService(
        repositoryResources: NolonRepositoryResources(skillsDirectories: [], workflows: [], mcps: []),
        localRepositories: []
    )
}

private func makeRemoteCatalogItem(
    slug: String,
    displayName: String? = nil,
    summary: String,
    updatedAt: Date = Date(timeIntervalSince1970: 0)
) -> NolonRemoteCatalogItem {
    NolonRemoteCatalogItem(
        kind: .skill,
        slug: slug,
        displayName: displayName ?? slug,
        summary: summary,
        latestVersion: "1.0.0",
        updatedAt: updatedAt,
        downloads: nil,
        stars: nil,
        installs: nil
    )
}

struct MultiMatchRemoteSearchMockSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base = makeRemoteSearchBaseService()

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let items = [
            makeRemoteCatalogItem(slug: "xcode", displayName: "Xcode", summary: "Xcode skill"),
            makeRemoteCatalogItem(slug: "xcodebuildmcp", summary: "xcodebuildmcp skill"),
        ]
        return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: items)
    }
}

struct ManyMatchRemoteSearchMockSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base = makeRemoteSearchBaseService()

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let items = (1...20).map { index in
            makeRemoteCatalogItem(
                slug: "skill-\(index)",
                displayName: "Skill \(index)",
                summary: "summary \(index)"
            )
        }
        return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: items)
    }
}

struct RateLimitedRemoteSearchMockSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base = makeRemoteSearchBaseService()

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        throw NolonCoreCLIError.executionFailed("Failed to run command: Remote list failed with status 429")
    }
}

struct PermissionDeniedRemoteSearchMockSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base = makeRemoteSearchBaseService()

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        throw NolonCoreCLIError.executionFailed("Operation not permitted")
    }
}

struct RemoteCatalogUnavailableMockSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base = makeRemoteSearchBaseService()

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        throw NolonCoreCLIError.executionFailed("Failed to run command: Remote list failed with status 404")
    }
}

struct LongSummaryRemoteSearchMockSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base = makeRemoteSearchBaseService()

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let summary = """
        Xcode long summary line one
        line two and line three with additional details that should be compacted into one single line for CLI readability and then truncated because it is too long for concise output.
        """
        let item = makeRemoteCatalogItem(slug: "xcode", displayName: "Xcode", summary: summary)
        return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [item])
    }
}

struct FutureDateRemoteSearchMockSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base = makeRemoteSearchBaseService()

    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let item = makeRemoteCatalogItem(
            slug: "xcode",
            displayName: "Xcode",
            summary: "Xcode skill",
            updatedAt: Date(timeIntervalSince1970: 4_102_444_800)
        )
        return NolonRemoteListResult(kind: kind, baseURL: baseURL, query: query, limit: limit, items: [item])
    }
}

struct DryRunInstallGuardMockSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base: MockSkillsRepositoryService

    init(
        repositoryResources: NolonRepositoryResources? = nil,
        localRepositories: [NolonLocalRepositorySummary]? = nil
    ) {
        let fallbackBase = makeRemoteSearchBaseService()
        self.base = MockSkillsRepositoryService(
            repositoryResources: repositoryResources ?? fallbackBase.repositoryResources,
            localRepositories: localRepositories ?? fallbackBase.localRepositories
        )
    }

    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        throw NolonCoreCLIError.executionFailed("install should not be called during dry-run")
    }
}

struct InstalledAndBrokenSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base = MockSkillsRepositoryService()

    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        NolonSkillMigrateScanResult(
            providerPath: providerPath.url.path,
            globalSkillsPath: globalSkillsPath.url.path,
            states: [
                NolonProviderSkillState(skillID: "xcode", path: providerPath.subpath("xcode").url.path, state: .installed),
                NolonProviderSkillState(skillID: "find-skills", path: providerPath.subpath("find-skills").url.path, state: .broken),
            ]
        )
    }
}

struct OrphanedAndBrokenSkillsRepositoryService: DelegatingMockSkillsRepositoryService {
    let base = makeRemoteSearchBaseService()

    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        NolonSkillMigrateScanResult(
            providerPath: providerPath.url.path,
            globalSkillsPath: globalSkillsPath.url.path,
            states: [
                NolonProviderSkillState(skillID: "agent-browser", path: providerPath.subpath("agent-browser").url.path, state: .orphaned),
                NolonProviderSkillState(skillID: "find-skills", path: providerPath.subpath("find-skills").url.path, state: .broken),
            ]
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
}
