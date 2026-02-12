import Foundation
import STFilePath

public struct NolonCoreCLIRunner: Sendable {
    public typealias FileReader = @Sendable (String) throws -> String

    private let service: any NolonSkillsRepositoryServing
    private let fileReader: FileReader

    public init(
        service: any NolonSkillsRepositoryServing = NolonLiveSkillsRepositoryService(),
        fileReader: @escaping FileReader = { path in
            try STFile(path).read()
        }
    ) {
        self.service = service
        self.fileReader = fileReader
    }

    public func execute(arguments: [String]) async -> NolonCLIExecutionResult {
        do {
            let command = try NolonCoreCLICommandParser.parse(arguments)
            let success = try await executeCommand(command)
            return NolonCLIExecutionResult(exitCode: 0, stdout: success, stderr: "")
        } catch let error as NolonCoreCLIError {
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: errorJSON(for: error))
        } catch {
            let wrapped = NolonCoreCLIError.executionFailed(error.localizedDescription)
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: errorJSON(for: wrapped))
        }
    }

    private func executeCommand(_ command: NolonCoreCLICommand) async throws -> String {
        switch command {
        case let .skillsRepoPlan(source, repositoriesRoot, pullStrategy, credentialStrategy, accessToken):
            let plan = try service.planGitImport(
                source: source,
                repositoriesRoot: STFolder(repositoriesRoot)
            )
            let preflight = try service.preflightGitSync(
                source: source,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
            return try encodeSuccess(
                command: command.commandID,
                data: PlanPayload(plan: plan, preflight: preflight)
            )

        case let .skillsRepoPreflight(source, pullStrategy, credentialStrategy, accessToken):
            let result = try service.preflightGitSync(
                source: source,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
            return try encodeSuccess(
                command: command.commandID,
                data: PreflightPayload(result: result)
            )

        case let .skillsRepoSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy):
            let plan = try service.planGitImport(
                source: source,
                repositoriesRoot: STFolder(repositoriesRoot)
            )
            let result = try await service.syncGitRepository(
                plan: plan,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
            let resources = service.discoverRepositoryResources(
                at: STFolder(plan.localClonePath),
                maxDepth: 5
            )
            return try encodeSuccess(
                command: command.commandID,
                data: SyncPayload(plan: plan, result: result, resources: resources)
            )

        case let .skillsInstall(skillPath, skillID, providerPath, installMethod):
            let result = try service.installSkill(
                skillPath: STPath(skillPath),
                skillID: skillID,
                providerPath: STFolder(providerPath),
                installMethod: installMethod
            )
            return try encodeSuccess(command: command.commandID, data: SkillInstallPayload(result: result))

        case let .skillsUninstall(skillID, providerPath):
            let result = try service.uninstallSkill(
                skillID: skillID,
                providerPath: STFolder(providerPath)
            )
            return try encodeSuccess(command: command.commandID, data: SkillUninstallPayload(result: result))

        case let .skillsMigrateScan(providerPath, globalSkillsPath):
            let result = try service.scanProviderSkills(
                providerPath: STFolder(providerPath),
                globalSkillsPath: STFolder(globalSkillsPath)
            )
            return try encodeSuccess(command: command.commandID, data: SkillMigrateScanPayload(result: result))

        case let .skillsMigrateApply(skillID, providerPath, globalSkillsPath, installMethod):
            let result = try service.migrateSkill(
                skillID: skillID,
                providerPath: STFolder(providerPath),
                globalSkillsPath: STFolder(globalSkillsPath),
                installMethod: installMethod
            )
            return try encodeSuccess(command: command.commandID, data: SkillMigrateApplyPayload(result: result))

        case let .skillsDiscover(path, maxDepth):
            let directories = service.discoverSkillsDirectories(
                at: STFolder(path),
                maxDepth: maxDepth
            )
            return try encodeSuccess(
                command: command.commandID,
                data: DiscoverPayload(path: path, maxDepth: maxDepth, directories: directories)
            )

        case let .skillsParse(file, directoryName):
            let content = try fileReader(file)
            let metadata = service.parseSkillMetadata(content: content, directoryName: directoryName)
            return try encodeSuccess(
                command: command.commandID,
                data: ParsePayload(file: file, metadata: metadata)
            )

        case let .resourcesDiscover(path, maxDepth):
            let resources = service.discoverRepositoryResources(
                at: STFolder(path),
                maxDepth: maxDepth
            )
            return try encodeSuccess(
                command: command.commandID,
                data: ResourceDiscoverPayload(path: path, maxDepth: maxDepth, resources: resources)
            )

        case let .resourcesInstall(kind, filePath, resourceName, targetPath, installMethod):
            let result = try service.installResource(
                kind: kind,
                filePath: STPath(filePath),
                resourceName: resourceName,
                targetPath: STFolder(targetPath),
                installMethod: installMethod
            )
            return try encodeSuccess(command: command.commandID, data: ResourceInstallPayload(result: result))

        case let .resourcesUninstall(kind, resourceName, targetPath):
            let result = try service.uninstallResource(
                kind: kind,
                resourceName: resourceName,
                targetPath: STFolder(targetPath)
            )
            return try encodeSuccess(command: command.commandID, data: ResourceUninstallPayload(result: result))

        case let .remoteList(kind, query, limit, baseURL):
            let result = try await service.listRemoteResources(
                kind: kind,
                query: query,
                limit: limit,
                baseURL: baseURL
            )
            return try encodeSuccess(command: command.commandID, data: RemoteListPayload(result: result))

        case let .remoteDownload(kind, slug, version, baseURL):
            let result = try await service.downloadRemoteResource(
                kind: kind,
                slug: slug,
                version: version,
                baseURL: baseURL
            )
            return try encodeSuccess(command: command.commandID, data: RemoteDownloadPayload(result: result))
        }
    }

    private func encodeSuccess<Payload: Encodable & Sendable>(command: String, data: Payload) throws -> String {
        let envelope = NolonCLISuccessEnvelope(command: command, data: data)
        return try encodeJSON(envelope)
    }

    private func errorJSON(for error: NolonCoreCLIError) -> String {
        (try? encodeJSON(
            NolonCLIErrorEnvelope(
                code: error.code,
                message: error.errorDescription ?? "Unknown error",
                detail: error.detail
            )
        ))
            ?? "{\"ok\":false,\"error\":{\"code\":\"execution_failed\",\"message\":\"Unknown error\"}}"
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}

private struct PlanPayload: Encodable, Sendable {
    let plan: NolonGitImportPlan
    let preflight: NolonGitSyncPreflight
}

private struct SyncPayload: Encodable, Sendable {
    let plan: NolonGitImportPlan
    let result: NolonGitSyncResult
    let resources: NolonRepositoryResources
}

private struct PreflightPayload: Encodable, Sendable {
    let result: NolonGitSyncPreflight
}

private struct DiscoverPayload: Encodable, Sendable {
    let path: String
    let maxDepth: Int
    let directories: [NolonSkillsDirectoryCandidate]
}

private struct SkillInstallPayload: Encodable, Sendable {
    let result: NolonSkillInstallResult
}

private struct SkillUninstallPayload: Encodable, Sendable {
    let result: NolonSkillUninstallResult
}

private struct SkillMigrateScanPayload: Encodable, Sendable {
    let result: NolonSkillMigrateScanResult
}

private struct SkillMigrateApplyPayload: Encodable, Sendable {
    let result: NolonSkillInstallResult
}

private struct ParsePayload: Encodable, Sendable {
    let file: String
    let metadata: NolonSkillStandardMetadata?
}

private struct ResourceDiscoverPayload: Encodable, Sendable {
    let path: String
    let maxDepth: Int
    let resources: NolonRepositoryResources
}

private struct ResourceInstallPayload: Encodable, Sendable {
    let result: NolonResourceInstallResult
}

private struct ResourceUninstallPayload: Encodable, Sendable {
    let result: NolonResourceUninstallResult
}

private struct RemoteListPayload: Encodable, Sendable {
    let result: NolonRemoteListResult
}

private struct RemoteDownloadPayload: Encodable, Sendable {
    let result: NolonRemoteDownloadResult
}
