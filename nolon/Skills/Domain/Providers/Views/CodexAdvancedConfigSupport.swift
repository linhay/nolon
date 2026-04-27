import AppKit
import Observation
import ProviderCatalog
import SwiftUI
import UniformTypeIdentifiers
import STFilePath
import CodexProvider
import NolonResourceKit
import NolonUI
import NolonUIFoundation

enum CodexAdvancedDocs {
    static let configBasics = "https://developers.openai.com/codex/config-basic"
    static let configAdvanced = "https://developers.openai.com/codex/config-advanced"
    static let configReference = "https://developers.openai.com/codex/config-reference"
    static let sandboxing = "https://developers.openai.com/codex/concepts/sandboxing"
    static let approvals = "https://developers.openai.com/codex/agent-approvals-security"
    static let subagents = "https://developers.openai.com/codex/concepts/subagents"
    static let models = "https://developers.openai.com/codex/models"
    static let compaction = "https://developers.openai.com/codex/compaction"
}

enum CodexLinkFolder: String, CaseIterable, Identifiable, Hashable {
    case prompts
    case rules
    case skills

    var id: String { rawValue }
}

struct CodexLinkState: Sendable {
    let folder: CodexLinkFolder
    let sourceURL: URL
    let targetURL: URL
    let isLinked: Bool
    let hasVisibleEntries: Bool
}

struct CodexLinkConflict: Identifiable {
    let folder: CodexLinkFolder
    let targetURL: URL

    var id: String { folder.rawValue }
}

struct CodexConfigDocLink: Identifiable, Sendable {
    let id: String
    let title: String
    let url: String
}

struct CodexAdvancedStructuredDraft: Sendable {
    let approvalPolicy: String?
    let sandboxMode: String?
    let webSearch: String?
    let modelProvider: String?
    let profile: String?
    let personality: String?
    let hideAgentReasoning: Bool?
    let modelAutoCompactTokenLimit: Int?
    let compactPrompt: String?
    let experimentalCompactPromptFile: String?
    let reasoningSummary: String?
    let verbosity: String?
    let historyPersistence: String?
    let historyMaxBytes: Int?
    let featureValues: [String: Bool]
    let agentsMaxThreads: Int?
    let agentsMaxDepth: Int?
    let roleDrafts: [CodexAgentRoleDraft]
    let preservedTopLevelRawValues: [String: String]
    let preservedHistoryRawValues: [String: String]
    let preservedRoleRawValues: [String: [String: String]]
}

struct CodexStructuredConfigPatchService: Sendable {
    private struct SectionBlock: Equatable {
        let name: String
        let header: String
        var body: [String]

        var renderedLines: [String] { [header] + body }
    }

    private struct Document: Equatable {
        var preamble: [String]
        var sections: [SectionBlock]
        let hasTrailingNewline: Bool
    }

    private let controlledTopLevelKeys: [String] = [
        "approval_policy",
        "sandbox_mode",
        "web_search",
        "model_provider",
        "profile",
        "personality",
        "hide_agent_reasoning",
        "model_auto_compact_token_limit",
        "compact_prompt",
        "experimental_compact_prompt_file",
        "model_reasoning_summary",
        "model_verbosity"
    ]

    private let controlledHistoryKeys: [String] = [
        "persistence",
        "max_bytes"
    ]

    private let controlledRoleKeys: [String] = [
        "description",
        "config_file",
        "model",
        "model_reasoning_effort",
        "model_reasoning_summary",
        "model_verbosity",
        "approval_policy",
        "sandbox_mode",
        "personality",
        "web_search"
    ]

    func patch(original: String, draft: CodexAdvancedStructuredDraft) throws -> String {
        var document = parseDocument(original.replacingOccurrences(of: "\r\n", with: "\n"))
        patchTopLevel(in: &document, draft: draft)
        patchHistory(in: &document, draft: draft)
        patchFeatures(in: &document, draft: draft)
        patchAgents(in: &document, draft: draft)
        return renderDocument(document)
    }

    func extractDraft(from original: String) -> CodexAdvancedStructuredDraft {
        let document = parseDocument(original.replacingOccurrences(of: "\r\n", with: "\n"))
        let topLevelAssignments = Dictionary(uniqueKeysWithValues: document.preamble.compactMap { line -> (String, String)? in
            guard let key = parseAssignmentKey(from: line), let value = parseRawAssignmentValue(from: line) else { return nil }
            return (key, value)
        })
        let preservedTopLevelRawValues = preservedRawValues(
            keys: controlledTopLevelKeys,
            assignments: topLevelAssignments,
            typedKeys: stringKeys.union(boolKeys).union(intKeys)
        )

        let featureValues = document.sections
            .first(where: { $0.name == "features" })
            .map(parseBooleanAssignments(in:)) ?? [:]

        let historySection = document.sections.first(where: { $0.name == "history" })
        let historyAssignments = historySection.map(parseRawAssignments(in:)) ?? [:]
        let preservedHistoryRawValues = preservedRawValues(
            keys: controlledHistoryKeys,
            assignments: historyAssignments,
            typedKeys: historyStringKeys.union(historyIntKeys)
        )

        let agentsSection = document.sections.first(where: { $0.name == "agents" })
        let roles = document.sections
            .filter { $0.name.hasPrefix("agents.") }
            .map { section -> CodexAgentRoleDraft in
                let roleName = String(section.name.dropFirst("agents.".count))
                let values = parseAssignments(in: section)
                return CodexAgentRoleDraft(
                    name: roleName,
                    description: values["description"] ?? "",
                    configFile: values["config_file"] ?? "",
                    model: values["model"] ?? "",
                    modelReasoningEffort: values["model_reasoning_effort"] ?? "",
                    modelReasoningSummary: values["model_reasoning_summary"] ?? "",
                    modelVerbosity: values["model_verbosity"] ?? "",
                    sandboxMode: values["sandbox_mode"] ?? "",
                    approvalPolicy: values["approval_policy"] ?? "",
                    personality: values["personality"] ?? "",
                    webSearch: values["web_search"] ?? ""
                )
            }
        let preservedRoleRawValues = Dictionary(
            uniqueKeysWithValues: document.sections
                .filter { $0.name.hasPrefix("agents.") }
                .compactMap { section -> (String, [String: String])? in
                    let roleName = String(section.name.dropFirst("agents.".count))
                    let rawAssignments = parseRawAssignments(in: section)
                    let preserved = preservedRawValues(
                        keys: controlledRoleKeys,
                        assignments: rawAssignments,
                        typedKeys: roleStringKeys
                    )
                    guard !preserved.isEmpty else { return nil }
                    return (roleName, preserved)
                }
        )

        return CodexAdvancedStructuredDraft(
            approvalPolicy: parseStringValue(for: "approval_policy", in: topLevelAssignments),
            sandboxMode: parseStringValue(for: "sandbox_mode", in: topLevelAssignments),
            webSearch: parseStringValue(for: "web_search", in: topLevelAssignments),
            modelProvider: parseStringValue(for: "model_provider", in: topLevelAssignments),
            profile: parseStringValue(for: "profile", in: topLevelAssignments),
            personality: parseStringValue(for: "personality", in: topLevelAssignments),
            hideAgentReasoning: parseBoolValue(for: "hide_agent_reasoning", in: topLevelAssignments),
            modelAutoCompactTokenLimit: parseIntValue(for: "model_auto_compact_token_limit", in: topLevelAssignments),
            compactPrompt: parseStringValue(for: "compact_prompt", in: topLevelAssignments),
            experimentalCompactPromptFile: parseStringValue(for: "experimental_compact_prompt_file", in: topLevelAssignments),
            reasoningSummary: parseStringValue(for: "model_reasoning_summary", in: topLevelAssignments),
            verbosity: parseStringValue(for: "model_verbosity", in: topLevelAssignments),
            historyPersistence: parseStringValue(for: "persistence", in: historyAssignments),
            historyMaxBytes: parseIntValue(for: "max_bytes", in: historyAssignments),
            featureValues: featureValues,
            agentsMaxThreads: agentsSection.flatMap { parseIntegerValue(for: "max_threads", in: $0) },
            agentsMaxDepth: agentsSection.flatMap { parseIntegerValue(for: "max_depth", in: $0) },
            roleDrafts: roles,
            preservedTopLevelRawValues: preservedTopLevelRawValues,
            preservedHistoryRawValues: preservedHistoryRawValues,
            preservedRoleRawValues: preservedRoleRawValues
        )
    }

    private func parseDocument(_ text: String) -> Document {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var preamble: [String] = []
        var sections: [SectionBlock] = []
        var currentSectionName: String?
        var currentSectionHeader: String?
        var currentBody: [String] = []

        func flushCurrentSection() {
            guard let currentSectionName, let currentSectionHeader else { return }
            sections.append(
                SectionBlock(
                    name: currentSectionName,
                    header: currentSectionHeader,
                    body: currentBody
                )
            )
        }

        for line in lines {
            if let sectionName = parseSectionName(from: line) {
                flushCurrentSection()
                currentSectionName = sectionName
                currentSectionHeader = line
                currentBody = []
                continue
            }

            if currentSectionName == nil {
                preamble.append(line)
            } else {
                currentBody.append(line)
            }
        }
        flushCurrentSection()
        return Document(
            preamble: preamble,
            sections: sections,
            hasTrailingNewline: text.hasSuffix("\n")
        )
    }

    private func renderDocument(_ document: Document) -> String {
        var lines = document.preamble
        for section in document.sections {
            lines.append(contentsOf: section.renderedLines)
        }
        var output = lines.joined(separator: "\n")
        if document.hasTrailingNewline || !output.isEmpty {
            output += "\n"
        }
        return output
    }

    private func patchTopLevel(in document: inout Document, draft: CodexAdvancedStructuredDraft) {
        let generated = compactGeneratedLines([
            generatedStringLine(key: "approval_policy", value: draft.approvalPolicy, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "sandbox_mode", value: draft.sandboxMode, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "web_search", value: draft.webSearch, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "model_provider", value: draft.modelProvider, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "profile", value: draft.profile, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "personality", value: draft.personality, preserved: draft.preservedTopLevelRawValues),
            generatedBoolLine(key: "hide_agent_reasoning", value: draft.hideAgentReasoning, preserved: draft.preservedTopLevelRawValues),
            generatedIntLine(key: "model_auto_compact_token_limit", value: draft.modelAutoCompactTokenLimit, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "compact_prompt", value: draft.compactPrompt, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "experimental_compact_prompt_file", value: draft.experimentalCompactPromptFile, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "model_reasoning_summary", value: draft.reasoningSummary, preserved: draft.preservedTopLevelRawValues),
            generatedStringLine(key: "model_verbosity", value: draft.verbosity, preserved: draft.preservedTopLevelRawValues)
        ])

        document.preamble = appendGeneratedLines(
            generated,
            to: filteredLines(in: document.preamble, removingKeys: Set(controlledTopLevelKeys))
        )
    }

    private func patchHistory(in document: inout Document, draft: CodexAdvancedStructuredDraft) {
        let generated = compactGeneratedLines([
            generatedStringLine(key: "persistence", value: draft.historyPersistence, preserved: draft.preservedHistoryRawValues),
            generatedIntLine(key: "max_bytes", value: draft.historyMaxBytes, preserved: draft.preservedHistoryRawValues)
        ])

        let sectionIndex = document.sections.firstIndex(where: { $0.name == "history" })
        let existingBody = sectionIndex.map { document.sections[$0].body } ?? []
        let filteredBody = appendGeneratedLines(
            generated,
            to: filteredLines(in: existingBody, removingKeys: Set(controlledHistoryKeys))
        )

        if !sectionHasMeaningfulContent(filteredBody) {
            if let sectionIndex {
                document.sections.remove(at: sectionIndex)
            }
            return
        }

        let section = SectionBlock(name: "history", header: "[history]", body: filteredBody)
        if let sectionIndex {
            document.sections[sectionIndex] = section
        } else {
            document.sections.append(section)
        }
    }

    private func patchFeatures(in document: inout Document, draft: CodexAdvancedStructuredDraft) {
        let controlledKeys = Set(draft.featureValues.keys)
        let generated = draft.featureValues
            .sorted { $0.key < $1.key }
            .map { boolAssignmentLine(key: $0.key, value: $0.value) }

        let sectionIndex = document.sections.firstIndex(where: { $0.name == "features" })
        let existingBody = sectionIndex.map { document.sections[$0].body } ?? []
        let filteredBody = patchBody(
            existingBody,
            removingKeys: controlledKeys,
            generatedLines: generated
        )

        if !sectionHasMeaningfulContent(filteredBody) {
            if let sectionIndex {
                document.sections.remove(at: sectionIndex)
            }
            return
        }

        let section = SectionBlock(name: "features", header: "[features]", body: filteredBody)
        if let sectionIndex {
            document.sections[sectionIndex] = section
        } else {
            document.sections.append(section)
        }
    }

    private func patchAgents(in document: inout Document, draft: CodexAdvancedStructuredDraft) {
        let agentsIndices = document.sections.indices.filter {
            let name = document.sections[$0].name
            return name == "agents" || name.hasPrefix("agents.")
        }
        let firstAgentsIndex = agentsIndices.first
        let existingSections = agentsIndices.map { document.sections[$0] }
        let existingParentSection = existingSections.first(where: { $0.name == "agents" })
        let existingRoleSections = existingSections.filter { $0.name.hasPrefix("agents.") }

        let parentGenerated = [
            intAssignmentLine(key: "max_threads", value: draft.agentsMaxThreads),
            intAssignmentLine(key: "max_depth", value: draft.agentsMaxDepth)
        ].compactMap { $0 }
        let patchedParentBody = patchBody(
            existingParentSection?.body ?? [],
            removingKeys: ["max_threads", "max_depth"],
            generatedLines: parentGenerated
        )

        var patchedCluster: [SectionBlock] = []
        let roleDraftsByName = Dictionary(uniqueKeysWithValues: draft.roleDrafts.compactMap { role -> (String, CodexAgentRoleDraft)? in
            let name = role.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return (name, role)
        })

        if sectionHasMeaningfulContent(patchedParentBody) || !roleDraftsByName.isEmpty {
            patchedCluster.append(
                SectionBlock(
                    name: "agents",
                    header: "[agents]",
                    body: patchedParentBody
                )
            )
        }

        var existingRoleNames = Set<String>()
        for section in existingRoleSections {
            let roleName = String(section.name.dropFirst("agents.".count))
            guard let roleDraft = roleDraftsByName[roleName] else { continue }
            existingRoleNames.insert(roleName)
            patchedCluster.append(
                SectionBlock(
                    name: section.name,
                    header: section.header,
                    body: patchRoleBody(section.body, role: roleDraft)
                )
            )
        }

        for role in draft.roleDrafts {
            let roleName = role.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !roleName.isEmpty, !existingRoleNames.contains(roleName) else { continue }
            patchedCluster.append(
                SectionBlock(
                    name: "agents.\(roleName)",
                    header: "[agents.\(roleName)]",
                    body: patchRoleBody([], role: role)
                )
            )
        }

        for index in agentsIndices.sorted(by: >) {
            document.sections.remove(at: index)
        }

        guard !patchedCluster.isEmpty else { return }
        let insertionIndex = firstAgentsIndex ?? document.sections.count
        document.sections.insert(contentsOf: patchedCluster, at: insertionIndex)
    }

    private func patchRoleBody(_ body: [String], role: CodexAgentRoleDraft) -> [String] {
        let preserved = role.preservedRawValues
        let generated = compactGeneratedLines([
            generatedStringLine(key: "description", value: normalized(role.description), preserved: preserved),
            generatedStringLine(key: "config_file", value: normalized(role.configFile), preserved: preserved),
            generatedStringLine(key: "model", value: normalized(role.model), preserved: preserved),
            generatedStringLine(key: "model_reasoning_effort", value: normalized(role.modelReasoningEffort), preserved: preserved),
            generatedStringLine(key: "model_reasoning_summary", value: normalized(role.modelReasoningSummary), preserved: preserved),
            generatedStringLine(key: "model_verbosity", value: normalized(role.modelVerbosity), preserved: preserved),
            generatedStringLine(key: "approval_policy", value: normalized(role.approvalPolicy), preserved: preserved),
            generatedStringLine(key: "sandbox_mode", value: normalized(role.sandboxMode), preserved: preserved),
            generatedStringLine(key: "personality", value: normalized(role.personality), preserved: preserved),
            generatedStringLine(key: "web_search", value: normalized(role.webSearch), preserved: preserved)
        ])

        return appendGeneratedLines(
            generated,
            to: filteredLines(in: body, removingKeys: Set(controlledRoleKeys))
        )
    }

    private func patchBody(
        _ body: [String],
        removingKeys: Set<String>,
        generatedLines: [String]
    ) -> [String] {
        appendGeneratedLines(generatedLines, to: filteredLines(in: body, removingKeys: removingKeys))
    }

    private func filteredLines(in lines: [String], removingKeys: Set<String>) -> [String] {
        var filtered: [String] = []
        for line in lines {
            guard let key = parseAssignmentKey(from: line), removingKeys.contains(key) else {
                filtered.append(line)
                continue
            }
        }
        return filtered
    }

    private func appendGeneratedLines(_ generatedLines: [String], to existingLines: [String]) -> [String] {
        guard !generatedLines.isEmpty else { return existingLines }
        var lines = existingLines
        while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeLast()
        }
        if let last = lines.last, !last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
        }
        lines.append(contentsOf: generatedLines)
        return lines
    }

    private func parseSectionName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]"), !trimmed.hasPrefix("[[") else { return nil }
        return String(trimmed.dropFirst().dropLast())
    }

    private func parseAssignmentKey(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            !trimmed.hasPrefix("#"),
            let equalIndex = trimmed.firstIndex(of: "=")
        else {
            return nil
        }
        let key = trimmed[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("[") else { return nil }
        return String(key)
    }

    private var stringKeys: Set<String> {
        [
            "approval_policy",
            "sandbox_mode",
            "web_search",
            "model_provider",
            "profile",
            "personality",
            "compact_prompt",
            "experimental_compact_prompt_file",
            "model_reasoning_summary",
            "model_verbosity"
        ]
    }

    private var boolKeys: Set<String> {
        ["hide_agent_reasoning"]
    }

    private var intKeys: Set<String> {
        ["model_auto_compact_token_limit"]
    }

    private var historyStringKeys: Set<String> {
        ["persistence"]
    }

    private var historyIntKeys: Set<String> {
        ["max_bytes"]
    }

    private var roleStringKeys: Set<String> {
        Set(controlledRoleKeys)
    }

    private func parseRawAssignments(in section: SectionBlock) -> [String: String] {
        Dictionary(uniqueKeysWithValues: section.body.compactMap { line -> (String, String)? in
            guard let key = parseAssignmentKey(from: line), let value = parseRawAssignmentValue(from: line) else { return nil }
            return (key, value)
        })
    }

    private func parseAssignments(in section: SectionBlock) -> [String: String] {
        Dictionary(uniqueKeysWithValues: section.body.compactMap { line -> (String, String)? in
            guard let key = parseAssignmentKey(from: line), let value = parseStringValue(from: line) else { return nil }
            return (key, value)
        })
    }

    private func parseBooleanAssignments(in section: SectionBlock) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: section.body.compactMap { line -> (String, Bool)? in
            guard let key = parseAssignmentKey(from: line), let value = parseBooleanValue(from: line) else { return nil }
            return (key, value)
        })
    }

    private func parseIntegerValue(for key: String, in section: SectionBlock) -> Int? {
        for line in section.body {
            guard parseAssignmentKey(from: line) == key else { continue }
            guard let equalIndex = line.firstIndex(of: "=") else { continue }
            let rawValue = line[line.index(after: equalIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(rawValue)
        }
        return nil
    }

    private func parseRawAssignmentValue(from line: String) -> String? {
        guard let equalIndex = line.firstIndex(of: "=") else { return nil }
        return line[line.index(after: equalIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseStringValue(for key: String, in assignments: [String: String]) -> String? {
        guard let raw = assignments[key] else { return nil }
        return parseStringValue(fromRawValue: raw)
    }

    private func parseBoolValue(for key: String, in assignments: [String: String]) -> Bool? {
        guard let raw = assignments[key] else { return nil }
        return parseBoolValue(fromRawValue: raw)
    }

    private func parseIntValue(for key: String, in assignments: [String: String]) -> Int? {
        guard let raw = assignments[key] else { return nil }
        return Int(raw)
    }

    private func parseStringValue(from line: String) -> String? {
        guard let rawValue = parseRawAssignmentValue(from: line) else { return nil }
        return parseStringValue(fromRawValue: rawValue)
    }

    private func parseStringValue(fromRawValue rawValue: String) -> String? {
        guard rawValue.hasPrefix("\""), rawValue.hasSuffix("\""), rawValue.count >= 2 else { return nil }
        let inner = rawValue.dropFirst().dropLast()
        return inner
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private func parseBooleanValue(from line: String) -> Bool? {
        guard let rawValue = parseRawAssignmentValue(from: line) else { return nil }
        return parseBoolValue(fromRawValue: rawValue)
    }

    private func parseBoolValue(fromRawValue rawValue: String) -> Bool? {
        switch rawValue {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    private func sectionHasMeaningfulContent(_ body: [String]) -> Bool {
        body.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#")
        }
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func preservedRawValues(
        keys: [String],
        assignments: [String: String],
        typedKeys: Set<String>
    ) -> [String: String] {
        Dictionary(uniqueKeysWithValues: keys.compactMap { key -> (String, String)? in
            guard let rawValue = assignments[key], typedKeys.contains(key) else { return nil }
            if stringKeys.contains(key), parseStringValue(fromRawValue: rawValue) != nil { return nil }
            if boolKeys.contains(key), parseBoolValue(fromRawValue: rawValue) != nil { return nil }
            if intKeys.contains(key), Int(rawValue) != nil { return nil }
            if historyStringKeys.contains(key), parseStringValue(fromRawValue: rawValue) != nil { return nil }
            if historyIntKeys.contains(key), Int(rawValue) != nil { return nil }
            if roleStringKeys.contains(key), parseStringValue(fromRawValue: rawValue) != nil { return nil }
            return (key, rawValue)
        })
    }

    private func stringAssignmentLine(key: String, value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\(key) = \"\(escaped)\""
    }

    private func boolAssignmentLine(key: String, value: Bool) -> String {
        "\(key) = \(value ? "true" : "false")"
    }

    private func intAssignmentLine(key: String, value: Int?) -> String? {
        guard let value else { return nil }
        return "\(key) = \(value)"
    }

    private func compactGeneratedLines(_ lines: [String?]) -> [String] {
        lines.compactMap { $0 }
    }

    private func generatedStringLine(key: String, value: String?, preserved: [String: String]) -> String? {
        if let line = stringAssignmentLine(key: key, value: value) {
            return line
        }
        guard let raw = preserved[key] else { return nil }
        return "\(key) = \(raw)"
    }

    private func generatedBoolLine(key: String, value: Bool?, preserved: [String: String]) -> String? {
        if let value {
            return boolAssignmentLine(key: key, value: value)
        }
        guard let raw = preserved[key] else { return nil }
        return "\(key) = \(raw)"
    }

    private func generatedIntLine(key: String, value: Int?, preserved: [String: String]) -> String? {
        if let value {
            return intAssignmentLine(key: key, value: value)
        }
        guard let raw = preserved[key] else { return nil }
        return "\(key) = \(raw)"
    }
}

struct CodexFeatureDefinition: Identifiable, Sendable {
    let key: String
    let maturity: String
    let description: String
    let source: String

    var id: String { key }
}

enum CodexFeatureSourceTag: String, CaseIterable {
    case coreFeatures
    case cliFeaturesList
    case appServer
    case codexDocs
    case nolonCompatibility
    case configUnknown

    var localizedTitle: String {
        switch self {
        case .coreFeatures:
            return NSLocalizedString("codex.features.source.tag.core_features", value: "Core Features", comment: "Core features source tag")
        case .cliFeaturesList:
            return NSLocalizedString("codex.features.source.tag.cli_features_list", value: "CLI Features List", comment: "CLI features list source tag")
        case .appServer:
            return NSLocalizedString("codex.features.source.tag.app_server", value: "App Server", comment: "App server source tag")
        case .codexDocs:
            return NSLocalizedString("codex.features.source.tag.codex_docs", value: "Codex Docs", comment: "Codex docs source tag")
        case .nolonCompatibility:
            return NSLocalizedString("codex.features.source.tag.nolon_compatibility", value: "Nolon Compatibility", comment: "Nolon compatibility source tag")
        case .configUnknown:
            return NSLocalizedString("codex.features.source.tag.config_unknown", value: "Config Unknown Key", comment: "Config unknown source tag")
        }
    }
}

struct CodexAgentRoleDraft: Identifiable, Equatable, Sendable {
    let id = UUID()
    var name: String
    var description: String
    var configFile: String
    var model: String
    var modelReasoningEffort: String
    var modelReasoningSummary: String
    var modelVerbosity: String
    var sandboxMode: String
    var approvalPolicy: String
    var personality: String
    var webSearch: String
    var preservedRawValues: [String: String] = [:]
}

enum CodexBuiltinAgentRole: String, CaseIterable, Identifiable {
    case `default`
    case worker
    case explorer
    case monitor

    var id: String { rawValue }

    var defaultDescription: String {
        switch self {
        case .default:
            return "General fallback role."
        case .worker:
            return "Execution-focused role for implementation and fixes."
        case .explorer:
            return "Read-focused role for repository exploration."
        case .monitor:
            return "Long-running task monitor role optimized for wait/poll workflows."
        }
    }
}

@MainActor
@Observable
final class CodexAdvancedConfigViewModel {
    var preferredModelDraft: String = ""
    var errorMessage: String?
    var pathStatus: CodexBinaryManager.CodexPathStatus?
    var isConfiguringPath = false
    var isCheckingPath = false
    var models: [CodexModelsCache.Model] = []
    var activeModelSlug: String?
    var selectedReasoningEffort: String?
    var isApplyingModel = false
    var isApplyingReasoning = false
    var modelsCacheSourcePath: String?
    var modelsCacheFetchedAt: Date?
    var modelsCacheClientVersion: String?
    var modelsCacheETag: String?
    var pendingConflict: CodexLinkConflict?
    var linkStates: [CodexLinkFolder: CodexLinkState] = [:]
    var applyingLinkFolders: Set<CodexLinkFolder> = []
    var configFileURL: URL?
    var isSavingConfig = false
    var configErrorMessage: String?
    var approvalPolicyDraft: String = ""
    var sandboxModeDraft: String = ""
    var webSearchDraft: String = ""
    var modelProviderDraft: String = ""
    var profileDraft: String = ""
    var personalityDraft: String = ""
    var hideAgentReasoningDraft: Bool?
    var modelAutoCompactTokenLimitDraft: String = ""
    var compactPromptDraft: String = ""
    var experimentalCompactPromptFileDraft: String = ""
    var reasoningSummaryDraft: String = ""
    var verbosityDraft: String = ""
    var historyPersistenceDraft: String = ""
    var historyMaxBytesDraft: String = ""
    var agentsMaxThreadsDraft: String = ""
    var agentsMaxDepthDraft: String = ""
    var featureValues: [String: Bool] = [:]
    var roleDrafts: [CodexAgentRoleDraft] = []
    var preservedTopLevelRawValues: [String: String] = [:]
    var preservedHistoryRawValues: [String: String] = [:]

    private var provider: Provider
    private let manager: CodexBinaryManager
    private let linkService: CodexLinkService
    private let modelPreferenceService: CodexModelPreferenceService
    private let patchService = CodexStructuredConfigPatchService()
    private var isHydratingStructuredDraft = false
    private var hasLoadedStructuredDraft = false

    nonisolated deinit {}

    static let supportedFeatures: [CodexFeatureDefinition] = [
        .init(key: "undo", maturity: "Stable", description: "Create a ghost commit at each turn.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "shell_tool", maturity: "Stable", description: "Enable the default shell tool.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "unified_exec", maturity: "Stable", description: "Use the unified PTY-backed exec tool.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "shell_snapshot", maturity: "Stable", description: "Snapshot shell env for repeated commands.", source: "codex docs + codex features list"),
        .init(key: "web_search_request", maturity: "Deprecated", description: "Legacy live web search toggle.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "web_search_cached", maturity: "Deprecated", description: "Legacy cached web search toggle.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "codex_hooks", maturity: "Under Development", description: "Enable lifecycle hooks loaded from hooks.json.", source: "codex docs"),
        .init(key: "fast_mode", maturity: "Stable", description: "Enable Fast mode selection and the service_tier fast path.", source: "codex docs"),
        .init(key: "search_tool", maturity: "Under Development", description: "Enable search_tool_bm25 tool discovery.", source: "codex-rs/core/src/features.rs"),
        .init(key: "runtime_metrics", maturity: "Under Development", description: "Show runtime metrics summaries in TUI.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "sqlite", maturity: "Under Development", description: "Persist rollout metadata to local SQLite.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "memory_tool", maturity: "Under Development", description: "Enable startup memory extraction and consolidation.", source: "codex-rs/core/src/features.rs"),
        .init(key: "child_agents_md", maturity: "Under Development", description: "Append additional AGENTS.md guidance.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "apply_patch_freeform", maturity: "Under Development", description: "Enable freeform apply_patch tool mode.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "exec_policy", maturity: "Under Development", description: "Enable exec policy pipeline.", source: "codex features list (local CLI)"),
        .init(key: "use_linux_sandbox_bwrap", maturity: "Under Development", description: "Use Linux bubblewrap sandbox pipeline.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "request_rule", maturity: "Stable", description: "Enable smart approval prefix rule suggestions.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "experimental_windows_sandbox", maturity: "Under Development", description: "Enable Windows restricted-token sandbox.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "elevated_windows_sandbox", maturity: "Under Development", description: "Enable elevated Windows sandbox runner.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "remote_compaction", maturity: "Under Development", description: "Enable remote compaction flow.", source: "codex features list (local CLI)"),
        .init(key: "remote_models", maturity: "Under Development", description: "Refresh remote model list before readiness.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "powershell_utf8", maturity: "Under Development", description: "Enforce UTF8 output in PowerShell.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "enable_request_compression", maturity: "Stable", description: "Enable compressed request bodies.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "collab", maturity: "Experimental", description: "Enable collab/sub-agent tools.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "apps", maturity: "Experimental", description: "Enable ChatGPT Apps/connectors support.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "smart_approvals", maturity: "Experimental", description: "Route eligible approval requests through the guardian reviewer subagent.", source: "codex docs"),
        .init(key: "skill_mcp_dependency_install", maturity: "Stable", description: "Allow installing missing MCP dependencies for skills.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "skill_env_var_dependency_prompt", maturity: "Under Development", description: "Prompt for missing skill env var dependencies.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "steer", maturity: "Stable", description: "Enable steer mode behavior.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "collaboration_modes", maturity: "Stable", description: "Enable collaboration modes such as plan mode.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "personality", maturity: "Stable", description: "Enable personality selection controls.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "responses_websockets", maturity: "Under Development", description: "Use Responses API WebSocket transport by default.", source: "codex-rs/core/src/features.rs + codex features list"),
        .init(key: "responses_websockets_v2", maturity: "Under Development", description: "Enable Responses API websocket v2 mode.", source: "codex-rs/core/src/features.rs"),
        .init(key: "multi_agent", maturity: "Stable", description: "Enable multi-agent collaboration tools.", source: "codex docs + Nolon config support"),
        .init(key: "apps_mcp_gateway", maturity: "Experimental", description: "Use the Apps MCP gateway endpoint.", source: "codex docs + Nolon config support"),
        .init(key: "web_search", maturity: "Deprecated", description: "Legacy web_search feature toggle.", source: "legacy compatibility (Nolon)"),
    ]

    init(
        provider: Provider,
        manager: CodexBinaryManager = .shared,
        linkService: CodexLinkService = CodexLinkService(),
        modelPreferenceService: CodexModelPreferenceService = CodexModelPreferenceService()
    ) {
        self.provider = provider
        self.manager = manager
        self.linkService = linkService
        self.modelPreferenceService = modelPreferenceService
    }

    func updateProvider(_ provider: Provider) {
        self.provider = provider
    }

    var isCodexXcodeProvider: Bool {
        if provider.templateId == "codexXcode" { return true }
        let expanded = (provider.defaultSkillsPath as NSString).expandingTildeInPath
        return expanded.contains("/Library/Developer/Xcode/CodingAssistant/codex")
    }

    var visibleModels: [CodexModelsCache.Model] {
        models.filter { model in
            let visibility = model.visibility?.lowercased()
            return visibility == nil || visibility == "list"
        }
    }

    var activeModel: CodexModelsCache.Model? {
        if let activeModelSlug {
            return models.first(where: { $0.slug == activeModelSlug })
        }
        return nil
    }

    var hasHiddenActiveModel: Bool {
        guard let activeModelSlug else { return false }
        guard models.contains(where: { $0.slug == activeModelSlug }) else { return false }
        return !visibleModels.contains(where: { $0.slug == activeModelSlug })
    }

    var availableReasoningEfforts: [String] {
        guard let activeModel else { return [] }
        var unique: [String] = []
        for effort in activeModel.supportedReasoningLevels.map(\.effort) {
            let trimmed = effort.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !unique.contains(trimmed) {
                unique.append(trimmed)
            }
        }
        return unique
    }

    func load() async {
        loadModelsCache()
        loadSelectionsFromConfig()
        loadConfigDraft()
        if isCodexXcodeProvider {
            pathStatus = nil
            refreshLinkStates()
        } else {
            await refreshPathStatus()
            linkStates = [:]
        }
    }

    func applySelectedModel() async {
        do {
            let trimmed = preferredModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            try await manager.applyModelToConfig(trimmed, configFile: resolvedConfigFile())
            preferredModelDraft = trimmed
            activeModelSlug = trimmed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearPreferredModel() async {
        do {
            try await manager.clearPreferredModel(configFile: resolvedConfigFile())
            preferredModelDraft = ""
            activeModelSlug = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func activateModel(_ model: CodexModelsCache.Model) async {
        isApplyingModel = true
        defer { isApplyingModel = false }
        do {
            try await manager.applyModelToConfig(model.slug, configFile: resolvedConfigFile())
            activeModelSlug = model.slug
            preferredModelDraft = model.slug
            await normalizeReasoningEffortForActiveModel(persist: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyReasoningEffort(_ effort: String?) async {
        let normalized = effort?.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = availableReasoningEfforts
        if let normalized, !normalized.isEmpty, !options.contains(normalized) {
            return
        }
        isApplyingReasoning = true
        defer { isApplyingReasoning = false }
        do {
            try await manager.setModelReasoningEffort(
                normalized?.isEmpty == false ? normalized : nil,
                configFile: resolvedConfigFile()
            )
            selectedReasoningEffort = normalized?.isEmpty == false ? normalized : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openModelConfig() {
        let configFile = resolvedConfigFile()
        let configPath = configFile ?? STFile("\(NSHomeDirectory())/.codex/config.toml")
        do {
            if !configPath.isExists {
                let initialModel = preferredModelDraft.nonEmpty ?? "gpt-5.3-codex"
                _ = try CodexConfigStore(file: configPath)
                    .setTopLevelStringValue(key: "model", value: initialModel)
            }
            NSWorkspace.shared.open(configPath.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshPathStatus() async {
        guard !isCodexXcodeProvider else {
            pathStatus = nil
            return
        }
        isCheckingPath = true
        defer { isCheckingPath = false }
        pathStatus = await manager.codexPathStatus()
    }

    func installPath() async {
        guard !isCodexXcodeProvider else { return }
        isConfiguringPath = true
        defer { isConfiguringPath = false }
        do {
            try await manager.installCodexPathToShellProfile()
            pathStatus = await manager.codexPathStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestSetLink(_ enabled: Bool, folder: CodexLinkFolder) async {
        if enabled {
            guard let state = linkStates[folder] else { return }
            if state.isLinked { return }
            if state.hasVisibleEntries {
                pendingConflict = CodexLinkConflict(folder: folder, targetURL: state.targetURL)
                return
            }
            await setLink(enabled: true, folder: folder)
            return
        }

        await setLink(enabled: false, folder: folder)
    }

    func confirmPendingConflict() async {
        guard let pendingConflict else { return }
        let folder = pendingConflict.folder
        self.pendingConflict = nil
        await setLink(enabled: true, folder: folder)
    }

    func openFinderForPendingConflict() {
        guard let pendingConflict else { return }
        NSWorkspace.shared.activateFileViewerSelecting([pendingConflict.targetURL])
    }

    func refreshLinkStates() {
        guard isCodexXcodeProvider else {
            linkStates = [:]
            return
        }

        var result: [CodexLinkFolder: CodexLinkState] = [:]
        for folder in CodexLinkFolder.allCases {
            let status = linkService.status(folder: map(folder), provider: provider)
            result[folder] = CodexLinkState(
                folder: folder,
                sourceURL: status.sourceURL,
                targetURL: status.targetURL,
                isLinked: status.isLinked,
                hasVisibleEntries: status.hasVisibleEntries
            )
        }
        linkStates = result
    }

    func linkState(for folder: CodexLinkFolder) -> CodexLinkState {
        if let cached = linkStates[folder] {
            return cached
        }
        let pair = linkService.linkPair(folder: map(folder), provider: provider)
        return CodexLinkState(
            folder: folder,
            sourceURL: pair.sourceURL,
            targetURL: pair.targetURL,
            isLinked: false,
            hasVisibleEntries: false
        )
    }

    private func setLink(enabled: Bool, folder: CodexLinkFolder) async {
        guard isCodexXcodeProvider else { return }
        applyingLinkFolders.insert(folder)
        defer { applyingLinkFolders.remove(folder) }

        do {
            try linkService.apply(enabled: enabled, folder: map(folder), provider: provider)
            refreshLinkStates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadModelsCache() {
        let snapshot = modelPreferenceService.loadModelsCache(for: provider)
        models = snapshot.models
        modelsCacheSourcePath = snapshot.sourcePath
        modelsCacheFetchedAt = snapshot.fetchedAt
        modelsCacheClientVersion = snapshot.clientVersion
        modelsCacheETag = snapshot.etag

        if let activeModelSlug, !models.contains(where: { $0.slug == activeModelSlug }) {
            self.activeModelSlug = nil
        }
    }

    func featureEnabled(_ key: String) -> Bool {
        featureValues[key] ?? false
    }

    func setFeature(_ key: String, enabled: Bool) {
        featureValues[key] = enabled
        if key == "multi_agent", !enabled {
            roleDrafts = []
            agentsMaxDepthDraft = ""
            agentsMaxThreadsDraft = ""
        }
    }

    static func makeEmptyRoleDraft() -> CodexAgentRoleDraft {
        CodexAgentRoleDraft(
            name: "",
            description: "",
            configFile: "",
            model: "",
            modelReasoningEffort: "",
            modelReasoningSummary: "",
            modelVerbosity: "",
            sandboxMode: "",
            approvalPolicy: "",
            personality: "",
            webSearch: ""
        )
    }

    static func makeBuiltinRoleDraft(_ builtinRole: CodexBuiltinAgentRole) -> CodexAgentRoleDraft {
        CodexAgentRoleDraft(
            name: builtinRole.rawValue,
            description: builtinRole.defaultDescription,
            configFile: "",
            model: "",
            modelReasoningEffort: "",
            modelReasoningSummary: "",
            modelVerbosity: "",
            sandboxMode: "",
            approvalPolicy: "",
            personality: "",
            webSearch: ""
        )
    }

    @discardableResult
    func addRoleDraft(_ role: CodexAgentRoleDraft? = nil) -> UUID {
        let role = role ?? Self.makeEmptyRoleDraft()
        roleDrafts.append(role)
        return role.id
    }

    @discardableResult
    func upsertBuiltinRole(_ builtinRole: CodexBuiltinAgentRole) -> UUID {
        if let index = roleDrafts.firstIndex(where: { $0.name == builtinRole.rawValue }) {
            roleDrafts[index].description = builtinRole.defaultDescription
            return roleDrafts[index].id
        }

        let role = Self.makeBuiltinRoleDraft(builtinRole)
        roleDrafts.append(role)
        return role.id
    }

    func removeRoleDraft(_ id: UUID) {
        roleDrafts.removeAll { $0.id == id }
    }

    func saveStructuredConfig() async {
        guard let configFile = resolvedConfigFile() else { return }
        isSavingConfig = true
        defer { isSavingConfig = false }

        do {
            _ = try CodexConfigStore(file: configFile).update { original in
                try patchService.patch(original: original, draft: makeStructuredDraft())
            }
            loadConfigDraft()
        } catch {
            configErrorMessage = error.localizedDescription
        }
    }

    func scheduleStructuredSaveIfReady() {
        guard hasLoadedStructuredDraft, !isHydratingStructuredDraft else { return }
        Task { await saveStructuredConfig() }
    }

    private func resolvedConfigFile() -> STFile? {
        modelPreferenceService.resolvedConfigFile(for: provider)
    }

    func loadConfigDraft() {
        guard let configFile = resolvedConfigFile() else { return }
        isHydratingStructuredDraft = true
        defer {
            isHydratingStructuredDraft = false
            hasLoadedStructuredDraft = true
        }
        configFileURL = configFile.url
        let original = (try? CodexConfigStore(file: configFile).readRaw()) ?? ""
        let draft = patchService.extractDraft(from: original)

        approvalPolicyDraft = draft.approvalPolicy ?? ""
        sandboxModeDraft = draft.sandboxMode ?? ""
        webSearchDraft = draft.webSearch ?? ""
        modelProviderDraft = draft.modelProvider ?? ""
        profileDraft = draft.profile ?? ""
        personalityDraft = draft.personality ?? ""
        hideAgentReasoningDraft = draft.hideAgentReasoning
        modelAutoCompactTokenLimitDraft = draft.modelAutoCompactTokenLimit.map(String.init) ?? ""
        compactPromptDraft = draft.compactPrompt ?? ""
        experimentalCompactPromptFileDraft = draft.experimentalCompactPromptFile ?? ""
        reasoningSummaryDraft = draft.reasoningSummary ?? ""
        verbosityDraft = draft.verbosity ?? ""
        historyPersistenceDraft = draft.historyPersistence ?? ""
        historyMaxBytesDraft = draft.historyMaxBytes.map(String.init) ?? ""
        agentsMaxThreadsDraft = draft.agentsMaxThreads.map(String.init) ?? ""
        agentsMaxDepthDraft = draft.agentsMaxDepth.map(String.init) ?? ""
        featureValues = draft.featureValues
        preservedTopLevelRawValues = draft.preservedTopLevelRawValues
        preservedHistoryRawValues = draft.preservedHistoryRawValues
        roleDrafts = draft.roleDrafts.map { role in
            var role = role
            role.preservedRawValues = draft.preservedRoleRawValues[role.name] ?? [:]
            return role
        }
    }

    private func loadSelectionsFromConfig() {
        guard let config = modelPreferenceService.loadConfig(for: provider) else {
            preferredModelDraft = ""
            activeModelSlug = nil
            selectedReasoningEffort = nil
            return
        }
        let model = config.model?.trimmingCharacters(in: .whitespacesAndNewlines)
        preferredModelDraft = model ?? ""
        activeModelSlug = model
        selectedReasoningEffort = config.modelReasoningEffort?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeReasoningEffortForActiveModel(persist: Bool) async {
        let options = availableReasoningEfforts
        if options.isEmpty {
            if persist {
                try? await manager.setModelReasoningEffort(nil, configFile: resolvedConfigFile())
            }
            selectedReasoningEffort = nil
            return
        }

        if let selectedReasoningEffort, options.contains(selectedReasoningEffort) {
            return
        }

        let fallback = [activeModel?.defaultReasoningLevel, options.first]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { options.contains($0) })

        selectedReasoningEffort = fallback
        if persist {
            try? await manager.setModelReasoningEffort(fallback, configFile: resolvedConfigFile())
        }
    }

    private func map(_ folder: CodexLinkFolder) -> CodexLinkFolderKind {
        switch folder {
        case .prompts: return .prompts
        case .rules: return .rules
        case .skills: return .skills
        }
    }

    private func makeStructuredDraft() -> CodexAdvancedStructuredDraft {
        CodexAdvancedStructuredDraft(
            approvalPolicy: approvalPolicyDraft.nonEmpty,
            sandboxMode: sandboxModeDraft.nonEmpty,
            webSearch: webSearchDraft.nonEmpty,
            modelProvider: modelProviderDraft.nonEmpty,
            profile: profileDraft.nonEmpty,
            personality: personalityDraft.nonEmpty,
            hideAgentReasoning: hideAgentReasoningDraft,
            modelAutoCompactTokenLimit: Int(modelAutoCompactTokenLimitDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
            compactPrompt: compactPromptDraft.nonEmpty,
            experimentalCompactPromptFile: experimentalCompactPromptFileDraft.nonEmpty,
            reasoningSummary: reasoningSummaryDraft.nonEmpty,
            verbosity: verbosityDraft.nonEmpty,
            historyPersistence: historyPersistenceDraft.nonEmpty,
            historyMaxBytes: Int(historyMaxBytesDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
            featureValues: featureValues,
            agentsMaxThreads: Int(agentsMaxThreadsDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
            agentsMaxDepth: Int(agentsMaxDepthDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
            roleDrafts: roleDrafts,
            preservedTopLevelRawValues: preservedTopLevelRawValues,
            preservedHistoryRawValues: preservedHistoryRawValues,
            preservedRoleRawValues: Dictionary(uniqueKeysWithValues: roleDrafts.compactMap { role in
                let name = role.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !role.preservedRawValues.isEmpty else { return nil }
                return (name, role.preservedRawValues)
            })
        )
    }
}
