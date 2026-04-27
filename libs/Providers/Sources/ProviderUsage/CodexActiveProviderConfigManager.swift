import Foundation
import Darwin
import STFilePath
import CodexProvider

struct CodexActiveProviderManagedConfigState: Sendable, Equatable, Codable {
    let configFilePath: String
    let configExistedBeforePatch: Bool
    let originalRawConfig: String
    let managedProviderID: String
    let managedAccountID: UUID
}

struct CodexActiveProviderConfigStateStore: Sendable {
    private let file: STFile

    init(file: STFile) {
        self.file = file
    }

    func load(configFilePath: String) -> CodexActiveProviderManagedConfigState? {
        loadAll()[configFilePath]
    }

    func save(_ state: CodexActiveProviderManagedConfigState) throws {
        var states = loadAll()
        states[state.configFilePath] = state
        try persist(states)
    }

    func remove(configFilePath: String) throws {
        var states = loadAll()
        states.removeValue(forKey: configFilePath)
        try persist(states)
    }

    private func loadAll() -> [String: CodexActiveProviderManagedConfigState] {
        guard let data = try? file.data(),
              !data.isEmpty
        else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: CodexActiveProviderManagedConfigState].self, from: data)) ?? [:]
    }

    private func persist(_ states: [String: CodexActiveProviderManagedConfigState]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(states)
        _ = file.parentFolder()?.createIfNotExists()
        try file.overlay(with: data)
    }
}

struct CodexActiveProviderConfigManager: Sendable {
    struct RelayConfig: Sendable, Equatable {
        let accountID: UUID
        let providerID: String
        let providerName: String
        let baseURL: String
        let queryParams: [String: String]
        let httpHeaders: [String: String]
        let model: String
        let modelReasoningEffort: String
    }

    private struct Document: Equatable {
        var preamble: [String]
        var sections: [String]
        let hasTrailingNewline: Bool
    }

    private let stateStore: CodexActiveProviderConfigStateStore
    private let controlledTopLevelKeys = ["model", "model_reasoning_effort", "model_provider"]

    init(stateStore: CodexActiveProviderConfigStateStore) {
        self.stateStore = stateStore
    }

    func applyRelayConfig(configFile: STFile, relay: RelayConfig) throws {
        let path = configFile.url.standardizedFileURL.path
        let store = CodexConfigStore(file: configFile)
        let current = normalizeConfigText((try? store.readRaw()) ?? "")
        let currentState = stateStore.load(configFilePath: path)
        let recoveredBaseline = currentState == nil ? inferredUnmanagedConfig(from: current) : nil
        let originalRawConfig = currentState?.originalRawConfig ?? recoveredBaseline ?? current
        let configExistedBeforePatch = currentState?.configExistedBeforePatch ?? configFile.isExists

        var document = parseDocument(currentState == nil ? (recoveredBaseline ?? current) : current)
        let sectionNamesToRemove = Set([
            currentState?.managedProviderID,
            relay.providerID,
        ].compactMap { $0 }.map { "model_providers.\($0)" })
        document.sections = removingSections(named: sectionNamesToRemove, from: document.sections)

        let patchedTopLevel = patch(
            document: document,
            assignments: [
                "model": relay.model,
                "model_reasoning_effort": relay.modelReasoningEffort,
                "model_provider": relay.providerID,
            ]
        )
        let parsedPatched = parseDocument(patchedTopLevel)
        var sections = parsedPatched.sections
        if !sections.isEmpty,
           sections.last?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty == false {
            sections.append("")
        }
        sections.append("[model_providers.\(relay.providerID)]")
        sections.append("name = \"\(escape(relay.providerName))\"")
        sections.append("base_url = \"\(escape(relay.baseURL))\"")
        if !relay.queryParams.isEmpty {
            sections.append("query_params = { \(renderInlineTable(relay.queryParams)) }")
        }
        if !relay.httpHeaders.isEmpty {
            sections.append("http_headers = { \(renderInlineTable(relay.httpHeaders)) }")
        }
        sections.append("requires_openai_auth = true")
        sections.append("wire_api = \"responses\"")

        let finalDocument = Document(
            preamble: parsedPatched.preamble,
            sections: sections,
            hasTrailingNewline: true
        )

        let nextState = CodexActiveProviderManagedConfigState(
            configFilePath: path,
            configExistedBeforePatch: configExistedBeforePatch,
            originalRawConfig: originalRawConfig,
            managedProviderID: relay.providerID,
            managedAccountID: relay.accountID
        )
        try stateStore.save(nextState)

        _ = try store.update { _ in render(document: finalDocument) }
    }

    func restoreManagedConfig(configFile: STFile) throws {
        let path = configFile.url.standardizedFileURL.path
        guard let state = stateStore.load(configFilePath: path) else {
            try restoreManagedConfigWithoutStateIfNeeded(configFile: configFile)
            return
        }

        let current = normalizeConfigText((try? CodexConfigStore(file: configFile).readRaw()) ?? "")
        let restored = restoredConfigPreservingCurrentChanges(
            current: current,
            baseline: state.originalRawConfig,
            managedProviderID: state.managedProviderID
        )

        if state.configExistedBeforePatch == false &&
            restored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            try removeFileIfPresent(configFile)
        } else {
            _ = try CodexConfigStore(file: configFile).update { _ in restored }
        }
        try stateStore.remove(configFilePath: path)
    }

    func managedState(configFile: STFile) -> CodexActiveProviderManagedConfigState? {
        stateStore.load(configFilePath: configFile.url.standardizedFileURL.path)
    }

    func baselineProviderID(configFile: STFile, defaultProviderID: String = "openai") -> String {
        let original = managedState(configFile: configFile)?.originalRawConfig
            ?? normalizeConfigText((try? CodexConfigStore(file: configFile).readRaw()) ?? "")
        let document = parseDocument(original)
        for line in document.preamble {
            guard parseAssignmentKey(from: line) == "model_provider",
                  let value = parseAssignmentValue(from: line)
            else {
                continue
            }
            return value
        }
        return defaultProviderID
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
            return controlledTopLevelKeys.contains(key) == false
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

        return render(document: Document(
            preamble: preamble,
            sections: document.sections,
            hasTrailingNewline: document.hasTrailingNewline
        ))
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

    private func restoreManagedConfigWithoutStateIfNeeded(configFile: STFile) throws {
        let current = normalizeConfigText((try? CodexConfigStore(file: configFile).readRaw()) ?? "")
        guard let restored = inferredUnmanagedConfig(from: current) else {
            return
        }

        if restored.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            try removeFileIfPresent(configFile)
            return
        }

        _ = try CodexConfigStore(file: configFile).update { _ in restored }
    }

    private func removingSections(named sectionNames: Set<String>, from lines: [String]) -> [String] {
        guard !lines.isEmpty, !sectionNames.isEmpty else { return lines }
        var result: [String] = []
        result.reserveCapacity(lines.count)
        var skippingCurrentSection = false

        for line in lines {
            if let parsedSectionName = parseSectionName(from: line) {
                skippingCurrentSection = sectionNames.contains(parsedSectionName)
                if skippingCurrentSection {
                    continue
                }
            }
            if !skippingCurrentSection {
                result.append(line)
            }
        }

        while result.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            _ = result.popLast()
        }
        return result
    }

    private func inferredUnmanagedConfig(from current: String) -> String? {
        let document = parseDocument(current)
        guard let managedProviderID = managedProviderID(from: document),
              hasManagedRelaySection(providerID: managedProviderID, in: document.sections)
        else {
            return nil
        }

        return render(document: strippingManagedRelayFragment(from: document, managedProviderID: managedProviderID))
    }

    private func restoredConfigPreservingCurrentChanges(
        current: String,
        baseline: String,
        managedProviderID: String
    ) -> String {
        let baselineDocument = parseDocument(baseline)
        let unmanagedCurrent = strippingManagedRelayFragment(
            from: parseDocument(current),
            managedProviderID: managedProviderID
        )

        let preamble = mergePreamble(
            baseline: baselineDocument.preamble,
            current: unmanagedCurrent.preamble
        )
        let sections = mergeSections(
            baseline: baselineDocument.sections,
            current: unmanagedCurrent.sections
        )

        return render(document: Document(
            preamble: preamble,
            sections: sections,
            hasTrailingNewline: unmanagedCurrent.hasTrailingNewline || baselineDocument.hasTrailingNewline
        ))
    }

    private func strippingManagedRelayFragment(
        from document: Document,
        managedProviderID: String
    ) -> Document {
        let strippedPreamble = document.preamble.filter { line in
            guard let key = parseAssignmentKey(from: line) else { return true }
            return controlledTopLevelKeys.contains(key) == false
        }

        let strippedSections = removingSections(
            named: ["model_providers.\(managedProviderID)"],
            from: document.sections
        )

        return Document(
            preamble: trimTrailingEmptyLines(from: strippedPreamble),
            sections: strippedSections,
            hasTrailingNewline: document.hasTrailingNewline
        )
    }

    private func mergePreamble(baseline: [String], current: [String]) -> [String] {
        var currentAssignments: [String: String] = [:]
        var currentExtraLines: [String] = []
        for line in current {
            if let key = parseAssignmentKey(from: line) {
                currentAssignments[key] = line
            } else if baseline.contains(line) == false {
                currentExtraLines.append(line)
            }
        }

        var baselineAssignmentKeys: Set<String> = []
        var merged: [String] = []
        for line in baseline {
            guard let key = parseAssignmentKey(from: line) else {
                merged.append(line)
                continue
            }
            baselineAssignmentKeys.insert(key)
            if controlledTopLevelKeys.contains(key) {
                merged.append(line)
            } else if let currentLine = currentAssignments[key] {
                merged.append(currentLine)
            } else {
                merged.append(line)
            }
        }

        for line in current {
            if let key = parseAssignmentKey(from: line) {
                guard baselineAssignmentKeys.contains(key) == false else { continue }
                merged.append(line)
            }
        }
        merged.append(contentsOf: currentExtraLines)

        return trimTrailingEmptyLines(from: merged)
    }

    private func mergeSections(baseline: [String], current: [String]) -> [String] {
        let baselineBlocks = sectionBlocks(from: baseline)
        let currentBlocks = sectionBlocks(from: current)
        let currentByName = Dictionary(uniqueKeysWithValues: currentBlocks.map { ($0.name, $0.lines) })
        let baselineNames = Set(baselineBlocks.map(\.name))

        var merged: [String] = []
        for block in baselineBlocks {
            merged.append(contentsOf: currentByName[block.name] ?? block.lines)
        }
        for block in currentBlocks where baselineNames.contains(block.name) == false {
            if !merged.isEmpty, merged.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                merged.append("")
            }
            merged.append(contentsOf: block.lines)
        }

        return trimTrailingEmptyLines(from: merged)
    }

    private func sectionBlocks(from lines: [String]) -> [(name: String, lines: [String])] {
        var blocks: [(name: String, lines: [String])] = []
        var currentName: String?
        var currentLines: [String] = []

        for line in lines {
            if let sectionName = parseSectionName(from: line) {
                if let currentName {
                    blocks.append((name: currentName, lines: trimTrailingEmptyLines(from: currentLines)))
                }
                currentName = sectionName
                currentLines = [line]
            } else if currentName != nil {
                currentLines.append(line)
            }
        }

        if let currentName {
            blocks.append((name: currentName, lines: trimTrailingEmptyLines(from: currentLines)))
        }

        return blocks
    }

    private func managedProviderID(from document: Document) -> String? {
        for line in document.preamble {
            guard parseAssignmentKey(from: line) == "model_provider",
                  let value = parseAssignmentValue(from: line)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else {
                continue
            }
            return value
        }
        return nil
    }

    private func hasManagedRelaySection(providerID: String, in lines: [String]) -> Bool {
        let sectionName = "model_providers.\(providerID)"
        var isInTargetSection = false
        var hasBaseURL = false
        var requiresOpenAIAuth = false
        var wireAPIResponses = false

        for line in lines {
            if let parsedSectionName = parseSectionName(from: line) {
                if isInTargetSection {
                    break
                }
                isInTargetSection = parsedSectionName == sectionName
                continue
            }
            guard isInTargetSection, let key = parseAssignmentKey(from: line) else {
                continue
            }
            let value = parseAssignmentValue(from: line)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            switch key {
            case "base_url":
                hasBaseURL = value?.isEmpty == false
            case "requires_openai_auth":
                requiresOpenAIAuth = value == "true"
            case "wire_api":
                wireAPIResponses = value == "responses"
            default:
                continue
            }
        }

        return hasBaseURL && requiresOpenAIAuth && wireAPIResponses
    }

    private func trimTrailingEmptyLines(from lines: [String]) -> [String] {
        var trimmed = lines
        while trimmed.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            _ = trimmed.popLast()
        }
        return trimmed
    }

    private func renderInlineTable(_ entries: [String: String]) -> String {
        entries.keys.sorted().map { key in
            let value = entries[key] ?? ""
            return "\"\(escape(key))\" = \"\(escape(value))\""
        }.joined(separator: ", ")
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

    private func parseAssignmentValue(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.hasPrefix("#") == false,
              let equalIndex = trimmed.firstIndex(of: "=")
        else {
            return nil
        }

        var value = String(trimmed[trimmed.index(after: equalIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let commentIndex = value.firstIndex(of: "#") {
            value = String(value[..<commentIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            return String(value.dropFirst().dropLast())
        }
        return value
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
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
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
