import Foundation
import ProviderCatalog
import STFilePath

public enum ProviderSkillStateKind: String, Sendable, Equatable {
    case installed
    case orphaned
    case broken
}

public extension ProviderSkillStateKind {
    var healthState: ResourceHealthState {
        switch self {
        case .installed: return .installed
        case .orphaned: return .orphaned
        case .broken: return .broken
        }
    }

    init(_ healthState: ResourceHealthState) {
        switch healthState {
        case .installed: self = .installed
        case .orphaned: self = .orphaned
        case .broken: self = .broken
        }
    }
}

public struct ProviderSkillStateItem: Sendable, Equatable {
    public let skillID: String
    public let path: String
    public let state: ProviderSkillStateKind

    public init(skillID: String, path: String, state: ProviderSkillStateKind) {
        self.skillID = skillID
        self.path = path
        self.state = state
    }
}

public struct ProviderSkillScanResult: Sendable, Equatable {
    public let providerPath: String
    public let globalSkillsPath: String
    public let states: [ProviderSkillStateItem]

    public init(providerPath: String, globalSkillsPath: String, states: [ProviderSkillStateItem]) {
        self.providerPath = providerPath
        self.globalSkillsPath = globalSkillsPath
        self.states = states
    }
}

public struct ProviderSkillInstallResult: Sendable, Equatable {
    public let skillID: String
    public let sourcePath: String
    public let targetPath: String
    public let installMethod: SkillInstallationMethod

    public init(
        skillID: String,
        sourcePath: String,
        targetPath: String,
        installMethod: SkillInstallationMethod
    ) {
        self.skillID = skillID
        self.sourcePath = sourcePath
        self.targetPath = targetPath
        self.installMethod = installMethod
    }
}

public struct ProviderSkillUninstallResult: Sendable, Equatable {
    public let skillID: String
    public let targetPath: String
    public let removed: Bool

    public init(skillID: String, targetPath: String, removed: Bool) {
        self.skillID = skillID
        self.targetPath = targetPath
        self.removed = removed
    }
}

public final class ProviderSkillMaintenanceService: @unchecked Sendable {
    private let nolonManager: NolonManager

    public init(nolonManager: NolonManager = .shared) {
        self.nolonManager = nolonManager
    }

    public func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> ProviderSkillScanResult {
        guard let scannableProviderPath = SkillInstallRootResolver.resolvedScannableFolder(providerPath: providerPath) else {
            throw SkillError.fileOperationFailed("Provider path does not exist: \(providerPath.url.path)")
        }

        let entries = try scannableProviderPath.subFilePaths([.skipsHiddenFiles])
        let globalRoot = globalSkillsPath.url.path.hasSuffix("/")
            ? globalSkillsPath.url.path
            : "\(globalSkillsPath.url.path)/"
        let providerUsesGlobalRoot = SkillInstallRootResolver.resolvedProviderRootIfMatchesExpectedRoot(
            providerPath: providerPath,
            expectedRoot: globalSkillsPath
        ) != nil

        let states = entries.map { path -> ProviderSkillStateItem in
            let skillID = path.url.lastPathComponent
            let reportedPath = providerPath.subpath(skillID).url.path
            let globalCandidate = globalSkillsPath.subpath(skillID).url.path
            let globalExists = STPath(globalCandidate).isExists
            if path.isSymbolicLink {
                let dest = ((try? path.destinationOfSymbolicLink()) ?? path).url.path
                if STPath(dest).isExists {
                    if providerUsesGlobalRoot {
                        return ProviderSkillStateItem(skillID: skillID, path: reportedPath, state: .installed)
                    }
                    if dest.hasPrefix(globalRoot) {
                        return ProviderSkillStateItem(skillID: skillID, path: reportedPath, state: .installed)
                    }
                    return ProviderSkillStateItem(skillID: skillID, path: reportedPath, state: .orphaned)
                }
                return ProviderSkillStateItem(skillID: skillID, path: reportedPath, state: .broken)
            }
            if providerUsesGlobalRoot {
                return ProviderSkillStateItem(skillID: skillID, path: reportedPath, state: .installed)
            }
            if globalExists {
                return ProviderSkillStateItem(skillID: skillID, path: reportedPath, state: .orphaned)
            }
            return ProviderSkillStateItem(skillID: skillID, path: reportedPath, state: .orphaned)
        }.sorted { $0.skillID.localizedCaseInsensitiveCompare($1.skillID) == .orderedAscending }

        return ProviderSkillScanResult(
            providerPath: providerPath.url.path,
            globalSkillsPath: globalSkillsPath.url.path,
            states: states
        )
    }

    public func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: SkillInstallationMethod
    ) throws -> ProviderSkillInstallResult {
        let resolvedSkillID = try validateSinglePathComponent(skillID, field: "skill-id")
        let source = globalSkillsPath.subpath(resolvedSkillID)
        guard source.isExists else {
            throw SkillError.skillNotFound(id: resolvedSkillID)
        }
        return try installSkill(
            skillPath: source,
            skillID: resolvedSkillID,
            providerPath: providerPath,
            installMethod: installMethod
        )
    }

    public func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: SkillInstallationMethod
    ) throws -> ProviderSkillInstallResult {
        try installSkillInternal(
            skillPath: skillPath,
            skillID: skillID,
            providerPath: providerPath,
            installMethod: installMethod
        )
    }

    public func repairSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: SkillInstallationMethod
    ) throws -> ProviderSkillInstallResult {
        let resolvedSkillID = try validateSinglePathComponent(skillID, field: "skill-id")
        let target = providerPath.subpath(resolvedSkillID)
        if target.isExists || target.isSymbolicLink {
            try target.deleteIncludingBrokenSymlink()
        }
        let source = globalSkillsPath.subpath(resolvedSkillID)
        guard source.isExists else {
            throw SkillError.skillNotFound(id: resolvedSkillID)
        }
        return try installSkill(
            skillPath: source,
            skillID: resolvedSkillID,
            providerPath: providerPath,
            installMethod: installMethod
        )
    }

    public func uninstallSkill(skillID: String, providerPath: STFolder) throws -> ProviderSkillUninstallResult {
        let resolvedSkillID = try validateSinglePathComponent(skillID, field: "skill-id")
        let target = providerPath.subpath(resolvedSkillID)
        let existed = target.isExists || target.isSymbolicLink
        if existed {
            try target.deleteIncludingBrokenSymlink()
        }
        return ProviderSkillUninstallResult(
            skillID: resolvedSkillID,
            targetPath: target.url.path,
            removed: existed
        )
    }

    private func installSkillInternal(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: SkillInstallationMethod
    ) throws -> ProviderSkillInstallResult {
        let source = skillPath
        guard source.isExists else {
            throw SkillError.fileOperationFailed("Skill path does not exist: \(skillPath.url.path)")
        }

        let resolvedSkillID: String
        if let skillID, !skillID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedSkillID = try validateSinglePathComponent(skillID, field: "skill-id")
        } else {
            resolvedSkillID = try validateSinglePathComponent(source.url.lastPathComponent, field: "skill-id")
        }

        let activeGlobalRoot = nolonManager.skillsFolder
        _ = activeGlobalRoot.createIfNotExists()
        _ = try? SkillInstallRootResolver.healManagedProviderRootIfNeeded(
            providerPath: providerPath,
            activeGlobalRoot: activeGlobalRoot
        )
        _ = providerPath.createIfNotExists()
        let targetPath = providerPath.subpath(resolvedSkillID)
        let linkedProviderRoot = SkillInstallRootResolver.resolvedProviderRootIfLinked(providerPath: providerPath)
            ?? SkillInstallRootResolver.resolvedProviderRootIfMatchesExpectedRoot(
                providerPath: providerPath,
                expectedRoot: activeGlobalRoot
            )

        if installMethod == .symlink,
           let linkedProviderRoot,
           let finalTarget = linkedProviderTarget(
               linkedProviderRoot: linkedProviderRoot,
               skillID: resolvedSkillID
           ) {
            let sourcePath = source.url.standardizedFileURL.path
            let finalTargetPath = finalTarget.url.standardizedFileURL.path

            if sourcePath != finalTargetPath {
                if finalTarget.isExists || finalTarget.isSymbolicLink {
                    try finalTarget.deleteIncludingBrokenSymlink()
                }
                try SkillContentMaterializer.copyMaterializingSymlinks(from: source, to: finalTarget)
            }

            return ProviderSkillInstallResult(
                skillID: resolvedSkillID,
                sourcePath: source.url.path,
                targetPath: targetPath.url.path,
                installMethod: .copy
            )
        }

        if targetPath.isExists || targetPath.isSymbolicLink {
            try targetPath.deleteIncludingBrokenSymlink()
        }

        switch installMethod {
        case .symlink:
            try targetPath.createSymbolicLink(to: source)
        case .copy:
            try SkillContentMaterializer.copyMaterializingSymlinks(from: source, to: targetPath)
        }

        return ProviderSkillInstallResult(
            skillID: resolvedSkillID,
            sourcePath: source.url.path,
            targetPath: targetPath.url.path,
            installMethod: installMethod
        )
    }

    private func linkedProviderTarget(linkedProviderRoot: STFolder, skillID: String) -> STPath? {
        let trimmed = skillID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return linkedProviderRoot.subpath(trimmed)
    }

    private func validateSinglePathComponent(_ value: String, field: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SkillError.fileOperationFailed("\(field) cannot be empty")
        }
        let candidateURL = URL(fileURLWithPath: trimmed)
        let basename = candidateURL.lastPathComponent
        guard basename == trimmed, trimmed != ".", trimmed != ".." else {
            throw SkillError.fileOperationFailed("\(field) must be a single path component: \(value)")
        }
        return trimmed
    }
}
