import Foundation
import STFilePath
import ProviderCatalog

/// Shared remote install orchestration used by both App entry view models.
struct RemoteInstallOrchestrator {
    typealias RemoteDownload = @Sendable (
        SkillsRepositoryFacade.RemoteCatalogKind,
        String,
        String?,
        String
    ) async throws -> URL

    let makeResourceInstaller: @Sendable () -> ResourceInstaller
    let downloadRemoteResource: RemoteDownload

    init(
        makeResourceInstaller: @escaping @Sendable () -> ResourceInstaller = {
            ResourceInstaller(globalCache: GlobalCacheRepository())
        },
        downloadRemoteResource: @escaping RemoteDownload = { kind, slug, version, baseURL in
            try await SkillsRepositoryFacade.downloadRemoteResource(
                kind: kind,
                slug: slug,
                version: version,
                baseURL: baseURL
            )
        }
    ) {
        self.makeResourceInstaller = makeResourceInstaller
        self.downloadRemoteResource = downloadRemoteResource
    }

    func installSkill(
        _ skill: RemoteSkill,
        to provider: Provider,
        installer: SkillInstaller,
        remoteBaseURL: String
    ) async throws {
        if let localPath = skill.localPath {
            try installer.installLocal(from: localPath, slug: skill.slug, to: provider)
            return
        }

        let zipURL = try await downloadRemoteResource(.skill, skill.slug, skill.latestVersion?.version, remoteBaseURL)
        defer { try? STPath(zipURL).deleteIncludingBrokenSymlink() }
        try installer.installRemote(zipURL: zipURL, slug: skill.slug, to: provider)
    }

    func installWorkflow(
        _ workflow: RemoteWorkflow,
        to provider: Provider,
        installer: SkillInstaller,
        remoteBaseURL: String
    ) async throws {
        if let localPath = workflow.localPath {
            try installer.installLocalWorkflow(
                fileURL: STPath(localPath).url,
                slug: workflow.slug,
                to: provider
            )
            return
        }

        let fileURL = try await downloadRemoteResource(
            .workflow,
            workflow.slug,
            workflow.latestVersion?.version,
            remoteBaseURL
        )
        defer { try? STPath(fileURL).deleteIncludingBrokenSymlink() }
        try installer.installRemoteWorkflow(fileURL: fileURL, slug: workflow.slug, to: provider)
    }

    func installMCP(
        _ mcp: RemoteMCP,
        to provider: Provider,
        remoteBaseURL: String
    ) async throws {
        let resourceInstaller = makeResourceInstaller()
        if let localPath = mcp.localPath {
            try await resourceInstaller.installFromLocal(
                resourceURL: STPath(localPath).url,
                resourceSlug: mcp.slug,
                resourceType: .mcp,
                to: provider
            )
            return
        }

        let resourceURL = try await downloadRemoteResource(.mcp, mcp.slug, mcp.latestVersion?.version, remoteBaseURL)
        defer { try? STPath(resourceURL).deleteIncludingBrokenSymlink() }
        try await resourceInstaller.installFromLocal(
            resourceURL: resourceURL,
            resourceSlug: mcp.slug,
            resourceType: .mcp,
            to: provider
        )
    }
}
