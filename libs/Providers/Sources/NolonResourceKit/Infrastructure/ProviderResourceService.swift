import Foundation
import ProviderCatalog
import STFilePath

public enum ProviderResourceKind: String, Sendable, CaseIterable {
    case workflow
    case rule
    case agent
}

public enum ProviderResourceState: String, Sendable, Equatable {
    case installed
    case orphaned
    case broken
}

public extension ProviderResourceState {
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

public enum ProviderAgentKind: String, Sendable, Equatable {
    case base
    case override
}

public struct ProviderResourceItem: Sendable, Equatable, Hashable {
    public let kind: ProviderResourceKind
    public let id: String
    public let name: String
    public let path: String
    public let preview: String
    public let relativePath: String?
    public let state: ProviderResourceState
    public let source: WorkflowSourceKind?
    public let agentKind: ProviderAgentKind?

    public init(
        kind: ProviderResourceKind,
        id: String,
        name: String,
        path: String,
        preview: String,
        relativePath: String? = nil,
        state: ProviderResourceState = .installed,
        source: WorkflowSourceKind? = nil,
        agentKind: ProviderAgentKind? = nil
    ) {
        self.kind = kind
        self.id = id
        self.name = name
        self.path = path
        self.preview = preview
        self.relativePath = relativePath
        self.state = state
        self.source = source
        self.agentKind = agentKind
    }
}

public enum ProviderResourceDraftKind: Sendable, Equatable {
    case workflow
    case rule
    case agentBase
    case agentOverride
}

public final class ProviderResourceService: @unchecked Sendable {
    private let fileManager: FileManager
    private let nolonManager: NolonManager

    public init(
        fileManager: FileManager = .default,
        nolonManager: NolonManager = .shared
    ) {
        self.fileManager = fileManager
        self.nolonManager = nolonManager
    }

    public func scanWorkflows(provider: Provider) -> [ProviderResourceItem] {
        let folder = STFolder(provider.workflowPath)
        guard folder.isExists else { return [] }
        let names = (try? fileManager.contentsOfDirectory(atPath: folder.url.path)) ?? []
        return names
            .filter { !$0.hasPrefix(".") && $0.lowercased().hasSuffix(".md") }
            .compactMap { name in
                let filePath = folder.subpath(name).url.path
                return parseWorkflow(atPath: filePath, idOverride: String(name.dropLast(3)))
            }
            .sorted { lhs, rhs in
                if lhs.state == rhs.state {
                    return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
                }
                return stateOrder(lhs.state) < stateOrder(rhs.state)
            }
    }

    public func scanRules(provider: Provider) -> [ProviderResourceItem] {
        guard isCodexProvider(provider) else { return [] }
        let baseDirectory = provider.codexRulesURL
        let basePath = baseDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let folder = STFolder(baseDirectory)
        guard folder.isExists else { return [] }

        guard let enumerator = fileManager.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [ProviderResourceItem] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true { continue }
            guard url.pathExtension.lowercased() == "rules" else { continue }

            if url.lastPathComponent.hasPrefix(".") { continue }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }

            let canonicalPath = url.resolvingSymlinksInPath().standardizedFileURL.path
            let relativePath: String
            if canonicalPath.hasPrefix(basePath + "/") {
                relativePath = String(canonicalPath.dropFirst(basePath.count + 1))
            } else {
                relativePath = url.lastPathComponent
            }
            let id = relativePath.replacingOccurrences(of: ".rules", with: "")
            items.append(
                ProviderResourceItem(
                    kind: .rule,
                    id: id,
                    name: url.deletingPathExtension().lastPathComponent,
                    path: url.path,
                    preview: firstNonEmptyLine(from: content),
                    relativePath: relativePath,
                    state: .installed,
                    source: nil,
                    agentKind: nil
                )
            )
        }

        return items.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    public func scanAgentDocs(provider: Provider) -> [ProviderResourceItem] {
        guard isCodexProvider(provider) else { return [] }
        var items: [ProviderResourceItem] = []

        let base = provider.codexAgentsFileURL
        if STFile(base).isExists, let item = parseAgentDoc(url: base, kind: .base) {
            items.append(item)
        }

        let override = provider.codexAgentsOverrideFile.url
        if STFile(override).isExists, let item = parseAgentDoc(url: override, kind: .override) {
            items.append(item)
        }

        return items.sorted { lhs, rhs in
            if lhs.agentKind == rhs.agentKind {
                return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
            }
            return lhs.agentKind == .override
        }
    }

    public func parseWorkflow(atPath path: String, idOverride: String? = nil) -> ProviderResourceItem? {
        let url = URL(fileURLWithPath: path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let fileName = url.deletingPathExtension().lastPathComponent
        let resourceID = idOverride.flatMap(Self.nonEmptyTrimmed(_:)) ?? fileName
        let metadata = FrontmatterParser.parseMetadata(from: content)
        guard let description = metadata["description"].flatMap(Self.nonEmptyTrimmed(_:)) else { return nil }
        let displayName = metadata["name"].flatMap(Self.nonEmptyTrimmed(_:)) ?? fileName

        let linkPath = url.path
        let filePath = STPath(url)
        let state: ProviderResourceState
        let source: WorkflowSourceKind

        if filePath.isSymbolicLink {
            let destination = (try? fileManager.destinationOfSymbolicLink(atPath: linkPath)) ?? ""
            let resolved = WorkflowSourceResolver.resolveSymlinkDestination(
                linkPath: linkPath,
                destination: destination
            )
            if !STPath(resolved).isExists {
                state = .broken
                source = .unknown
            } else {
                source = WorkflowSourceResolver.resolve(
                    workflowPath: linkPath,
                    resolvedPath: resolved,
                    nolonManager: nolonManager
                )
                state = source == .unknown ? .orphaned : .installed
            }
        } else {
            let inferred = inferWorkflowSourceByID(resourceID)
            source = inferred
            state = inferred == .unknown ? .orphaned : .installed
        }

        return ProviderResourceItem(
            kind: .workflow,
            id: resourceID,
            name: displayName,
            path: linkPath,
            preview: description,
            relativePath: nil,
            state: state,
            source: source,
            agentKind: nil
        )
    }

    public func deleteResource(atPath path: String) throws {
        try STPath(path).deleteIncludingBrokenSymlink()
    }

    public func deleteWorkflow(workflowID: String, provider: Provider) throws {
        let workflowFolder = STFolder(provider.workflowPath)
        let primary = workflowFolder.file("\(workflowID).md")
        if primary.isExists || primary.isSymbolicLink {
            try primary.deleteIncludingBrokenSymlink()
            return
        }
        let fallback = workflowFolder.file(workflowID)
        if fallback.isExists || fallback.isSymbolicLink {
            try fallback.deleteIncludingBrokenSymlink()
        }
    }

    public func createDraft(provider: Provider, kind: ProviderResourceDraftKind) throws -> URL {
        switch kind {
        case .workflow:
            let folder = STFolder(provider.workflowPath)
            _ = folder.createIfNotExists()
            var index = 1
            var candidate = folder.file("new-workflow-\(index).md")
            while candidate.isExists {
                index += 1
                candidate = folder.file("new-workflow-\(index).md")
            }
            try "".write(to: candidate.url, atomically: true, encoding: .utf8)
            return candidate.url
        case .rule:
            let folder = provider.codexRulesFolder
            _ = folder.createIfNotExists()
            var index = 1
            var candidate = folder.file("new-rule-\(index).rules")
            while candidate.isExists {
                index += 1
                candidate = folder.file("new-rule-\(index).rules")
            }
            try "".write(to: candidate.url, atomically: true, encoding: .utf8)
            return candidate.url
        case .agentBase:
            _ = provider.codexHomeFolder.createIfNotExists()
            if !provider.codexAgentsFile.isExists {
                try "".write(to: provider.codexAgentsFile.url, atomically: true, encoding: .utf8)
            }
            return provider.codexAgentsFile.url
        case .agentOverride:
            _ = provider.codexHomeFolder.createIfNotExists()
            if !provider.codexAgentsOverrideFile.isExists {
                try "".write(to: provider.codexAgentsOverrideFile.url, atomically: true, encoding: .utf8)
            }
            return provider.codexAgentsOverrideFile.url
        }
    }

    private func parseAgentDoc(url: URL, kind: ProviderAgentKind) -> ProviderResourceItem? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return ProviderResourceItem(
            kind: .agent,
            id: url.path,
            name: url.lastPathComponent,
            path: url.path,
            preview: firstNonEmptyLine(from: content),
            relativePath: nil,
            state: .installed,
            source: nil,
            agentKind: kind
        )
    }

    private func inferWorkflowSourceByID(_ workflowID: String) -> WorkflowSourceKind {
        let userPath = nolonManager.userWorkflowsFolder.file("\(workflowID).md").url.path
        if STFile(userPath).isExists { return .user }
        let skillPath = nolonManager.generatedWorkflowsFolder.file("\(workflowID).md").url.path
        if STFile(skillPath).isExists { return .skill }
        let mcpPath = nolonManager.mcpsWorkflowsFolder.file("\(workflowID).md").url.path
        if STFile(mcpPath).isExists { return .mcp }
        return .unknown
    }

    private func isCodexProvider(_ provider: Provider) -> Bool {
        provider.templateId == "codex" || provider.templateId == "codexXcode"
    }

    private func firstNonEmptyLine(from content: String) -> String {
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    private func stateOrder(_ state: ProviderResourceState) -> Int {
        switch state {
        case .broken: return 0
        case .orphaned: return 1
        case .installed: return 2
        }
    }
    private static func nonEmptyTrimmed(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
