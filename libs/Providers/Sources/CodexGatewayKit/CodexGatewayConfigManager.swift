import Foundation
import ProviderUsage
import STFilePath

public protocol CodexGatewayConfigManaging: Sendable {
    func patchGatewayConfig(configFile: STFile, config: CodexGatewayConfig) async throws
    func restoreGatewayConfig(configFile: STFile) async throws
}

public struct CodexGatewayManagedConfigState: Sendable, Equatable, Codable {
    public let configFilePath: String
    public let configExistedBeforePatch: Bool
    public let originalBaseURL: String?
    public let originalModelProvider: String?
    public let originalCLIAuthCredentialsStore: String?
    public let originalRawConfig: String?

    public init(
        configFilePath: String,
        configExistedBeforePatch: Bool,
        originalBaseURL: String?,
        originalModelProvider: String?,
        originalCLIAuthCredentialsStore: String?,
        originalRawConfig: String? = nil
    ) {
        self.configFilePath = configFilePath
        self.configExistedBeforePatch = configExistedBeforePatch
        self.originalBaseURL = originalBaseURL
        self.originalModelProvider = originalModelProvider
        self.originalCLIAuthCredentialsStore = originalCLIAuthCredentialsStore
        self.originalRawConfig = originalRawConfig
    }
}

public actor CodexGatewayManagedConfigStateStore {
    private let file: STFile

    public init(file: STFile) {
        self.file = file
    }

    public init(authManager: CodexAuthManager = CodexAuthManager()) {
        self.init(file: authManager.nolonCodexRootFolder().folder("gateway").file("config.json"))
    }

    public func load(configFilePath: String) async -> CodexGatewayManagedConfigState? {
        loadAll()[configFilePath]
    }

    public func save(_ state: CodexGatewayManagedConfigState) async throws {
        var states = loadAll()
        states[state.configFilePath] = state
        try persist(states)
    }

    public func remove(configFilePath: String) async throws {
        var states = loadAll()
        states.removeValue(forKey: configFilePath)
        try persist(states)
    }

    private func loadAll() -> [String: CodexGatewayManagedConfigState] {
        guard let data = try? file.data(),
              !data.isEmpty
        else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: CodexGatewayManagedConfigState].self, from: data)) ?? [:]
    }

    private func persist(_ states: [String: CodexGatewayManagedConfigState]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(states)
        _ = file.parentFolder()?.createIfNotExists()
        try file.overlay(with: data)
    }
}

public actor CodexGatewayConfigManager: CodexGatewayConfigManaging {
    private struct Document: Equatable {
        var preamble: [String]
        var sections: [String]
        let hasTrailingNewline: Bool
    }

    private let stateStore: CodexGatewayManagedConfigStateStore
    private let controlledKeys = ["base_url", "model_provider", "cli_auth_credentials_store"]
    private let gatewayProviderSectionName = "model_providers.nolon_gateway"
    private let gatewayProviderName = "Nolon Gateway"

    public init(stateStore: CodexGatewayManagedConfigStateStore = CodexGatewayManagedConfigStateStore()) {
        self.stateStore = stateStore
    }

    public func patchGatewayConfig(configFile: STFile, config: CodexGatewayConfig) async throws {
        let path = configFile.url.standardizedFileURL.path
        let original = normalizeConfigText((try? configFile.read()) ?? "")
        let document = parseDocument(original)
        let captured = captureOriginalState(
            configFilePath: path,
            document: document,
            existed: configFile.isExists,
            originalRawConfig: original
        )
        if await stateStore.load(configFilePath: path) == nil {
            try await stateStore.save(captured)
        }

        let rendered = patchGatewayDocument(document: document, config: config)
        _ = configFile.parentFolder()?.createIfNotExists()
        try configFile.overlay(with: rendered)
    }

    public func restoreGatewayConfig(configFile: STFile) async throws {
        let path = configFile.url.standardizedFileURL.path
        guard let state = await stateStore.load(configFilePath: path) else {
            return
        }
        if let originalRawConfig = state.originalRawConfig {
            if state.configExistedBeforePatch == false && originalRawConfig.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try removeFileIfPresent(configFile)
            } else {
                _ = configFile.parentFolder()?.createIfNotExists()
                try configFile.overlay(with: originalRawConfig)
            }
            try await stateStore.remove(configFilePath: path)
            return
        }

        let current = (try? configFile.read()) ?? ""
        let document = parseDocument(normalizeConfigText(current))
        let cleanedDocument = Document(
            preamble: document.preamble,
            sections: removingSection(named: gatewayProviderSectionName, from: document.sections),
            hasTrailingNewline: document.hasTrailingNewline
        )
        let rendered = patch(
            document: cleanedDocument,
            assignments: [
                "base_url": state.originalBaseURL,
                "model_provider": state.originalModelProvider,
                "cli_auth_credentials_store": state.originalCLIAuthCredentialsStore,
            ]
        )

        if state.configExistedBeforePatch == false && rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try removeFileIfPresent(configFile)
        } else {
            _ = configFile.parentFolder()?.createIfNotExists()
            try configFile.overlay(with: rendered)
        }
        try await stateStore.remove(configFilePath: path)
    }

    private func captureOriginalState(
        configFilePath: String,
        document: Document,
        existed: Bool,
        originalRawConfig: String
    ) -> CodexGatewayManagedConfigState {
        let assignments = Dictionary(uniqueKeysWithValues: document.preamble.compactMap { line -> (String, String)? in
            guard let key = parseAssignmentKey(from: line),
                  controlledKeys.contains(key),
                  let value = parseStringValue(from: line)
            else {
                return nil
            }
            return (key, value)
        })
        return CodexGatewayManagedConfigState(
            configFilePath: configFilePath,
            configExistedBeforePatch: existed,
            originalBaseURL: assignments["base_url"],
            originalModelProvider: assignments["model_provider"],
            originalCLIAuthCredentialsStore: assignments["cli_auth_credentials_store"],
            originalRawConfig: originalRawConfig
        )
    }

    private func patchGatewayDocument(document: Document, config: CodexGatewayConfig) -> String {
        let strippedDocument = Document(
            preamble: document.preamble,
            sections: removingSection(named: gatewayProviderSectionName, from: document.sections),
            hasTrailingNewline: document.hasTrailingNewline
        )
        let patchedTopLevel = patch(
            document: strippedDocument,
            assignments: [
                "base_url": nil,
                "model_provider": "nolon_gateway",
                "cli_auth_credentials_store": "file",
            ]
        )
        let parsedPatched = parseDocument(patchedTopLevel)
        var sections = parsedPatched.sections
        if !sections.isEmpty, sections.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            sections.append("")
        }
        sections.append("[\(gatewayProviderSectionName)]")
        sections.append("name = \"\(escape(gatewayProviderName))\"")
        sections.append("base_url = \"http://\(escape(config.host)):\(config.port)/v1\"")
        sections.append("wire_api = \"responses\"")
        let finalDocument = Document(
            preamble: parsedPatched.preamble,
            sections: sections,
            hasTrailingNewline: true
        )
        return render(document: finalDocument)
    }

    private func parseDocument(_ text: String) -> Document {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var preamble: [String] = []
        var sections: [String] = []
        var reachedSection = false

        for line in lines {
            if reachedSection == false, parseSectionName(from: line) == nil {
                preamble.append(line)
            } else {
                reachedSection = true
                sections.append(line)
            }
        }

        return Document(
            preamble: preamble,
            sections: sections,
            hasTrailingNewline: text.hasSuffix("\n")
        )
    }

    private func patch(document: Document, assignments: [String: String?]) -> String {
        let filtered = document.preamble.filter { line in
            guard let key = parseAssignmentKey(from: line) else { return true }
            return controlledKeys.contains(key) == false
        }

        let generated = assignments
            .sorted { $0.key < $1.key }
            .compactMap { key, value -> String? in
                guard let value else { return nil }
                return "\(key) = \"\(escape(value))\""
            }

        var preamble = filtered
        while preamble.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            _ = preamble.popLast()
        }
        if !generated.isEmpty && !preamble.isEmpty {
            preamble.append("")
        }
        preamble.append(contentsOf: generated)

        return render(
            document: Document(
                preamble: preamble,
                sections: document.sections,
                hasTrailingNewline: document.hasTrailingNewline
            )
        )
    }

    private func render(document: Document) -> String {
        var lines = document.preamble
        if !document.sections.isEmpty, !lines.isEmpty, lines.last?.isEmpty == false {
            lines.append("")
        }
        lines.append(contentsOf: document.sections)

        var output = lines.joined(separator: "\n")
        if document.hasTrailingNewline || !output.isEmpty {
            output += "\n"
        }
        return output
    }

    private func removingSection(named sectionName: String, from lines: [String]) -> [String] {
        guard !lines.isEmpty else { return lines }
        var result: [String] = []
        result.reserveCapacity(lines.count)
        var isSkippingTargetSection = false

        for line in lines {
            if let parsedSectionName = parseSectionName(from: line) {
                isSkippingTargetSection = parsedSectionName == sectionName
                if isSkippingTargetSection {
                    continue
                }
            }
            if !isSkippingTargetSection {
                result.append(line)
            }
        }

        while result.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            _ = result.popLast()
        }
        return result
    }

    private func normalizeConfigText(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
    }

    private func parseAssignmentKey(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.hasPrefix("#") == false,
              let equalIndex = trimmed.firstIndex(of: "=")
        else {
            return nil
        }
        return trimmed[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseStringValue(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let equalIndex = trimmed.firstIndex(of: "=") else { return nil }
        let rhs = trimmed[trimmed.index(after: equalIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard rhs.hasPrefix("\""), rhs.hasSuffix("\""), rhs.count >= 2 else {
            return nil
        }
        return String(rhs.dropFirst().dropLast())
    }

    private func parseSectionName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["),
              trimmed.hasSuffix("]"),
              trimmed.count >= 3
        else {
            return nil
        }
        return String(trimmed.dropFirst().dropLast())
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func removeFileIfPresent(_ file: STFile) throws {
        do {
            try FileManager.default.removeItem(at: file.url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            return
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == ENOENT {
            return
        }
    }
}
